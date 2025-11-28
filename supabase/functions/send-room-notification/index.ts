import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Type declarations for IDE
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const sanitizeUuid = (value: string | null | undefined) =>
  (value ?? '').replace(/"/g, '').trim()

const isValidUuid = (value: string) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)

const toBase64Url = (input: string) =>
  btoa(input)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')

const uint8ToBase64Url = (bytes: Uint8Array) => {
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return toBase64Url(binary)
}

const importPrivateKey = async (pem: string) => {
  const cleaned = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '')

  const binaryKey = atob(cleaned)
  const keyArray = new Uint8Array(binaryKey.length)
  for (let i = 0; i < binaryKey.length; i++) {
    keyArray[i] = binaryKey.charCodeAt(i)
  }

  return await crypto.subtle.importKey(
    'pkcs8',
    keyArray,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

const getAccessToken = async (serviceAccount: any) => {
  const now = Math.floor(Date.now() / 1000)

  const header = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = toBase64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))

  const unsignedToken = `${header}.${payload}`
  const encoder = new TextEncoder()
  const key = await importPrivateKey(serviceAccount.private_key)

  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(unsignedToken),
  )

  const signature = uint8ToBase64Url(new Uint8Array(signatureBuffer))
  const assertion = `${unsignedToken}.${signature}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  const json = await res.json()

  if (!res.ok) {
    throw new Error(`Failed to obtain access token: ${res.status} ${JSON.stringify(json)}`)
  }

  return json.access_token as string
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const {
      room_id,
      sender_id,
      title,
      body,
      sender_name,
      image_url,
      link,
    } = await req.json()

    const cleanSenderId = sanitizeUuid(sender_id)
    const cleanRoomId = (room_id ?? '').toString().replace(/"/g, '').trim()
    const cleanSenderName = (sender_name ?? '').toString().trim()
    const imageUrl = (image_url ?? '').toString().trim() || undefined
    const deepLink = (link ?? '').toString().trim() || undefined

    if (!cleanRoomId || !cleanSenderId) {
      return new Response(
        JSON.stringify({ error: 'room_id and sender_id are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    if (!isValidUuid(cleanSenderId)) {
      console.error('Invalid sender UUID received', { sender_id })
      return new Response(
        JSON.stringify({ error: 'Invalid sender_id format' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all room members
    const { data: members, error: membersError } = await supabase
      .from('room_members')
      .select('user_id')
      .eq('room_id', cleanRoomId)

    if (membersError) {
      throw membersError
    }

    if (!members || members.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No other members in the room' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Get FCM tokens for all members
    const userIds = members
      .map((m: any) => sanitizeUuid(m.user_id))
      .filter((id: string) => id)

    if (!userIds.length) {
      return new Response(
        JSON.stringify({ message: 'No other members in the room' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }
    const { data: tokens, error: tokensError } = await supabase
      .from('user_tokens')
      .select('token')
      .in('user_id', userIds)

    if (tokensError) {
      throw tokensError
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No FCM tokens found for room members' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // إعداد الاعتمادات لـ FCM HTTP v1
    const rawServiceAccount = Deno.env.get('FCM_SERVICE_ACCOUNT')
    if (!rawServiceAccount) {
      console.error('FCM_SERVICE_ACCOUNT secret is not set')
      return new Response(
        JSON.stringify({ error: 'Missing FCM service account configuration' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    let serviceAccountJson = rawServiceAccount.trim()
    if (!serviceAccountJson.startsWith('{')) {
      try {
        serviceAccountJson = new TextDecoder().decode(Uint8Array.from(atob(serviceAccountJson), c => c.charCodeAt(0)))
      } catch (decodeError) {
        console.error('Failed to decode FCM service account secret', decodeError)
        return new Response(
          JSON.stringify({ error: 'Invalid FCM service account format' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
        )
      }
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId = serviceAccount.project_id || Deno.env.get('FCM_PROJECT_ID')

    if (!projectId) {
      console.error('FCM project id is missing')
      return new Response(
        JSON.stringify({ error: 'Missing FCM project id' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    const fcmTokens = tokens.map((t: any) => t.token)
    console.log(`Prepared ${fcmTokens.length} FCM tokens for room ${cleanRoomId}`)

    const successes: string[] = []
    const failures: { token: string; status: number; body: string }[] = []

    const accessToken = await getAccessToken(serviceAccount)
    console.log('Obtained access token for FCM v1 request')

    const dataPayload: Record<string, string> = {
      room_id: cleanRoomId,
      sender_id: cleanSenderId,
      type: 'room_notification',
    }

    if (cleanSenderName) {
      dataPayload.sender_name = cleanSenderName
    }

    if (deepLink) {
      dataPayload.link = deepLink
    }

    if (imageUrl) {
      dataPayload.image_url = imageUrl
    }

    const finalTitle = (title ?? '').toString().trim() || 'تنبيه من الأصدقاء'
    const finalBody = (body ?? '').toString().trim() ||
      (cleanSenderName ? `${cleanSenderName} ينادي عليك` : 'ينادي عليك أحد أصدقائك')

    for (const token of fcmTokens) {
      const messageData = { ...dataPayload }

      const messagePayload = {
        message: {
          token,
          notification: {
            title: finalTitle,
            body: finalBody,
            ...(imageUrl ? { image: imageUrl } : {}),
          },
          data: messageData,
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'room_alerts_channel',
              sound: 'n1',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              ...(imageUrl ? { image: imageUrl } : {}),
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'n1.mp3',
                badge: 1,
                ...(imageUrl ? { 'mutable-content': 1 } : {}),
                category: 'ROOM_NOTIFICATION',
              },
            },
            ...(imageUrl ? { fcm_options: { image: imageUrl } } : {}),
          },
        },
      }

      try {
        const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(messagePayload),
        })

        const responseText = await response.text()
        console.log('FCM response status:', response.status, 'body:', responseText)

        if (response.ok) {
          successes.push(token)
        } else {
          failures.push({ token, status: response.status, body: responseText })
        }
      } catch (sendError) {
        console.error('FCM send error for token', token, sendError)
        failures.push({ token, status: 0, body: String(sendError) })
      }
    }

    return new Response(
      JSON.stringify({
        message: 'Notifications processed',
        recipients_count: successes.length,
        failures,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: failures.length ? 207 : 200 }
    )

  } catch (error: any) {
    console.error('Error sending notification:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

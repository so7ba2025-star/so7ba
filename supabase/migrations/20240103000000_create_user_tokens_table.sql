-- Create user_tokens table for storing FCM tokens
CREATE TABLE IF NOT EXISTS public.user_tokens (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.user_profiles(id) ON DELETE CASCADE NOT NULL,
  token text NOT NULL,
  device_id text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  
  -- Ensure each user has unique tokens per device
  UNIQUE (user_id, device_id)
);

-- Create index for faster lookups (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_user_tokens_user_id ON public.user_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tokens_token ON public.user_tokens(token);
CREATE INDEX IF NOT EXISTS idx_user_tokens_device_id ON public.user_tokens(device_id);

-- Enable RLS (Row Level Security)
ALTER TABLE public.user_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists, then create new one
DROP POLICY IF EXISTS "Users can manage their own tokens" ON public.user_tokens;
CREATE POLICY "Users can manage their own tokens" ON public.user_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Create trigger to update updated_at timestamp (only if function doesn't exist)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists, then create new one
DROP TRIGGER IF EXISTS handle_user_tokens_updated_at ON public.user_tokens;
CREATE TRIGGER handle_user_tokens_updated_at
  BEFORE UPDATE ON public.user_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

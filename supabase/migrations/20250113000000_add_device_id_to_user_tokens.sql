-- Add device_id column to user_tokens table
ALTER TABLE public.user_tokens ADD COLUMN IF NOT EXISTS device_id text;

-- Update unique constraint to include device_id
DROP INDEX IF EXISTS idx_user_tokens_user_device;
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_tokens_user_device ON public.user_tokens(user_id, device_id);

-- Update the policy to handle device_id
DROP POLICY IF EXISTS "Users can manage their own tokens" ON public.user_tokens;
CREATE POLICY "Users can manage their own tokens" ON public.user_tokens
  FOR ALL USING (auth.uid() = user_id);

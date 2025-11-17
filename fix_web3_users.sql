-- Fix for Web3 users: Make email nullable in users table

-- Step 1: Make email column nullable
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;

-- Step 2: Update unique constraint to allow multiple NULL emails
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_email_key;

-- Drop existing index if it exists
DROP INDEX IF EXISTS users_email_unique_idx;

-- For PostgreSQL 15+
-- ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE NULLS NOT DISTINCT (email);

-- For PostgreSQL < 15 (use partial unique index instead)
CREATE UNIQUE INDEX users_email_unique_idx ON public.users (email) WHERE email IS NOT NULL;

-- Step 3: Add wallet_address column to users table if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS wallet_address TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS chain TEXT;

-- Create index for wallet lookups
CREATE INDEX IF NOT EXISTS idx_users_wallet_address ON public.users(wallet_address);

-- Step 4: Update trigger function to handle NULL emails and wallet addresses
CREATE OR REPLACE FUNCTION handle_auth_user_creation()
RETURNS TRIGGER AS $$
DECLARE
  web3_identity JSONB;
  wallet_addr TEXT;
  chain_type TEXT;
BEGIN
  -- Get Web3 identity data if exists
  SELECT identity_data INTO web3_identity
  FROM auth.identities
  WHERE user_id = NEW.id
  AND provider = 'web3'
  LIMIT 1;
  
  -- Extract wallet address and chain from identity
  IF web3_identity IS NOT NULL THEN
    wallet_addr := web3_identity->>'wallet_address';
    chain_type := web3_identity->>'chain';
  END IF;
  
  INSERT INTO public.users (id, email, full_name, avatar_url, wallet_address, chain)
  VALUES (
    NEW.id,
    NEW.email,  -- Can be NULL for Web3 users
    COALESCE(
      NEW.raw_user_meta_data->>'full_name', 
      NEW.raw_user_meta_data->>'name',
      wallet_addr  -- Use wallet address from identity as display name
    ),
    NEW.raw_user_meta_data->>'avatar_url',
    wallet_addr,
    chain_type
  )
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(EXCLUDED.email, public.users.email),
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url),
    wallet_address = COALESCE(EXCLUDED.wallet_address, public.users.wallet_address),
    chain = COALESCE(EXCLUDED.chain, public.users.chain),
    updated_at = NOW();
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Ensure trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_auth_user_creation();

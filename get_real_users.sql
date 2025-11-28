-- Get real users from user_profiles table
SELECT 
    id,
    first_name,
    last_name,
    email,
    avatar_url,
    created_at
FROM user_profiles 
WHERE is_active = true
ORDER BY created_at ASC
LIMIT 10;

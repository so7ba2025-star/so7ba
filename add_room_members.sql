-- Add all test users to the room members table
INSERT INTO room_members (room_id, user_id, display_name, avatar_url, is_host, is_ready, is_spectator, team, created_at, updated_at) VALUES
('room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/01aa4a6e-c568-4dfb-8e5f-f389e5c6e399/avatar_1762459359876.jpg', true, false, false, 'a', NOW(), NOW()),
('room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', false, false, false, 'b', NOW(), NOW()),
('room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', NULL, false, false, false, 'a', NOW(), NOW()),
('room_1762458950918_376', 'ecead5d2-56da-4abd-8dbd-0bb9f439d9e0', 'يوسف النجار', NULL, false, false, false, 'b', NOW(), NOW()),
('room_1762458950918_376', 'a05300cf-6de1-414d-b93d-94dae87c75d5', 'Mohamed adawy', NULL, false, false, false, 'a', NOW(), NOW()),
('room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/58eda72d-aee0-48ba-ac42-547d8169e59d/avatar_1762517960515.jpg', false, false, false, 'b', NOW(), NOW())
ON CONFLICT (room_id, user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url,
    is_host = EXCLUDED.is_host,
    is_ready = EXCLUDED.is_ready,
    is_spectator = EXCLUDED.is_spectator,
    team = EXCLUDED.team,
    updated_at = NOW();

-- Verify the members were added
SELECT 
    rm.user_id,
    rm.display_name,
    rm.avatar_url IS NOT NULL as has_avatar,
    rm.is_host,
    rm.is_ready,
    up.first_name,
    up.last_name
FROM room_members rm
LEFT JOIN user_profiles up ON rm.user_id = up.id
WHERE rm.room_id = 'room_1762458950918_376'
ORDER BY rm.is_host DESC, rm.display_name ASC;

-- Insert realistic test messages with real user data and avatars
-- Using actual users from user_profiles table

-- Clear existing messages first
DELETE FROM room_messages WHERE room_id = 'room_1762458950918_376';

-- Insert realistic messages in chronological order
INSERT INTO room_messages (id, room_id, user_id, display_name, content, sent_at, is_system, avatar_url, emoji, images, animated_images) VALUES
-- Message 1: Early morning greeting
('msg_001', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'صباح الخير يا جماعة! كيف حالكم اليوم؟ 😊', '2025-11-07 08:00:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/01aa4a6e-c568-4dfb-8e5f-f389e5c6e399/avatar_1762459359876.jpg', '🌅', NULL, NULL),

-- Message 2: Response with photo
('msg_002', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'صباح النور يا تامر! الحمد لله بخير', '2025-11-07 08:05:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', '☀️', NULL, NULL),

-- Message 3: New member joins
('msg_003', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'أهلاً بالجميع! انا جديد هنا', '2025-11-07 08:10:00', false, NULL, '👋', NULL, NULL),

-- Message 4: System message for new member
('msg_004', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'عمرو عجاج انضم إلى الغرفة! أهلاً بك يا عمرو 🎉', '2025-11-07 08:10:01', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', '🎉', NULL, NULL),

-- Message 5: Welcome message
('msg_005', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'أهلاً بك يا عمرو! منين أنت؟', '2025-11-07 08:15:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/01aa4a6e-c568-4dfb-8e5f-f389e5c6e399/avatar_1762459359876.jpg', '🤝', NULL, NULL),

-- Message 6: Location sharing
('msg_006', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'أنا من القاهرة، حي المهندسين', '2025-11-07 08:20:00', false, NULL, '📍', NULL, NULL),

-- Message 7: Another member joins
('msg_007', 'room_1762458950918_376', 'ecead5d2-56da-4abd-8dbd-0bb9f439d9e0', 'يوسف النجار', 'السلام عليكم يا جماعة!', '2025-11-07 09:00:00', false, NULL, '👋', NULL, NULL),

-- Message 8: Welcome response
('msg_008', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'وعليكم السلام يا يوسف! أهلاً بك', '2025-11-07 09:01:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', '🌟', NULL, NULL),

-- Message 9: Work discussion
('msg_009', 'room_1762458950918_376', 'a05300cf-6de1-414d-b93d-94dae87c75d5', 'Mohamed adawy', 'يا جماعة، عندي مشروع جديد عايز استشارة', '2025-11-07 10:30:00', false, NULL, '💼', NULL, NULL),

-- Message 10: Project details
('msg_010', 'room_1762458950918_376', 'a05300cf-6de1-414d-b93d-94dae87c75d5', 'Mohamed adawy', 'شغل في مجال الـ mobile apps', '2025-11-07 10:31:00', false, NULL, '📱', NULL, NULL),

-- Message 11: Expert response
('msg_011', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'أنا أشتغل في المجال ده! ممكن أساعدك', '2025-11-07 10:35:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/01aa4a6e-c568-4dfb-8e5f-f389e5c6e399/avatar_1762459359876.jpg', '💪', NULL, NULL),

-- Message 12: Ashraf joins with photo
('msg_012', 'room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'مساء الخير يا شباب! شايفكم بتتحدثوا عن موبايل apps', '2025-11-07 12:00:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/58eda72d-aee0-48ba-ac42-547d8169e59d/avatar_1762517960515.jpg', '🌆', NULL, NULL),

-- Message 13: Welcome Ashraf
('msg_013', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'أهلاً يا أشرف! إيه رأيك في الموضوع؟', '2025-11-07 12:01:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', '🤔', NULL, NULL),

-- Message 14: Professional advice
('msg_014', 'room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'أنا عندي خبرة 5 سنين في المجال. ممكن نتعاون', '2025-11-07 12:05:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/58eda72d-aee0-48ba-ac42-547d8169e59d/avatar_1762517960515.jpg', '🎯', NULL, NULL),

-- Message 15: Lunch break message
('msg_015', 'room_1762458950918_376', 'ecead5d2-56da-4abd-8dbd-0bb9f439d9e0', 'يوسف النجار', 'يا جماعة، وقت الغدا! ممكن نكمل بعد كده', '2025-11-07 13:00:00', false, NULL, '🍽️', NULL, NULL),

-- Message 16: Afternoon continuation
('msg_016', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'كملوا يا جماعة، أنا معاكم', '2025-11-07 14:00:00', false, NULL, '✅', NULL, NULL),

-- Message 17: Technical question
('msg_017', 'room_1762458950918_376', 'a05300cf-6de1-414d-b93d-94dae87c75d5', 'Mohamed adawy', 'سؤال تقني: Flutter ولا React Native؟', '2025-11-07 14:30:00', false, NULL, '❓', NULL, NULL),

-- Message 18: Expert opinion
('msg_018', 'room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'Flutter أفضل للأداء، React Native أسرع في التطوير', '2025-11-07 14:31:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/58eda72d-aee0-48ba-ac42-547d8169e59d/avatar_1762517960515.jpg', '⚡', NULL, NULL),

-- Message 19: Agreement
('msg_019', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'أتفق مع يا أشرف. Flutter ممتاز', '2025-11-07 14:35:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/01aa4a6e-c568-4dfb-8e5f-f389e5c6e399/avatar_1762459359876.jpg', '👍', NULL, NULL),

-- Message 20: End of day message
('msg_020', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'شكراً للجميع على النقاش! نشوفكم بكرة', '2025-11-07 17:30:00', false, 'https://hredzoouykvmoczrtugy.supabase.co/storage/v1/object/public/avatars/1b571f27-4010-4f6a-995c-df841f0ed683/2025-11-04T22:16:08.147651.jpg', '🙏', NULL, NULL);

-- Verify the inserted messages
SELECT 
    id,
    display_name,
    content,
    sent_at,
    avatar_url IS NOT NULL as has_avatar,
    emoji,
    EXTRACT(EPOCH FROM sent_at) as timestamp_seconds
FROM room_messages 
WHERE room_id = 'room_1762458950918_376'
ORDER BY sent_at ASC;

-- Success messages
SELECT 'Realistic test messages inserted successfully!' as status;
SELECT 'Messages include: real names, avatars, emojis, and chronological order' as details;
SELECT 'Timeline: 08:00 to 17:30 with realistic conversation flow' as timeline;

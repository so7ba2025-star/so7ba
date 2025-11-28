-- Create room_messages table
CREATE TABLE room_messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    display_name TEXT NOT NULL,
    content TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_system BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    emoji TEXT,
    images TEXT[], -- Array of image URLs
    animated_images TEXT[], -- Array of animated image URLs
    audio_url TEXT,
    audio_duration_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_room_messages_room_id ON room_messages(room_id);
CREATE INDEX idx_room_messages_sent_at ON room_messages(sent_at DESC);
CREATE INDEX idx_room_messages_room_sent ON room_messages(room_id, sent_at DESC);

-- Function to get messages for a room with pagination
CREATE OR REPLACE FUNCTION get_room_messages(
    p_room_id TEXT,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
    id TEXT,
    room_id TEXT,
    user_id UUID,
    display_name TEXT,
    content TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    is_system BOOLEAN,
    avatar_url TEXT,
    emoji TEXT,
    images TEXT[],
    animated_images TEXT[],
    audio_url TEXT,
    audio_duration_ms INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rm.id,
        rm.room_id,
        rm.user_id,
        rm.display_name,
        rm.content,
        rm.sent_at,
        rm.is_system,
        rm.avatar_url,
        rm.emoji,
        rm.images,
        rm.animated_images,
        rm.audio_url,
        rm.audio_duration_ms
    FROM room_messages rm
    WHERE rm.room_id = p_room_id
    ORDER BY rm.sent_at ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

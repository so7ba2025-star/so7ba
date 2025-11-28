-- Simplified Feed Tables - Step by Step Creation
-- Run this after checking the schema with debug_schema.sql

-- Step 1: Create posts table without foreign key first
CREATE TABLE IF NOT EXISTS posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id UUID, -- Will add foreign key later
    title TEXT,
    content TEXT NOT NULL,
    content_type VARCHAR(20) DEFAULT 'text' CHECK (content_type IN ('text', 'image', 'video', 'article', 'poll', 'meme')),
    ai_summary TEXT,
    image_url TEXT,
    video_url TEXT,
    post_mode VARCHAR(20) DEFAULT 'connect' CHECK (post_mode IN ('learn', 'work', 'connect', 'chill')),
    type VARCHAR(20) DEFAULT 'post' CHECK (type IN ('post', 'job', 'question', 'discussion', 'fun')),
    metadata JSONB DEFAULT '{}',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    views_count INTEGER DEFAULT 0,
    saved_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'hidden', 'deleted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Create other tables without foreign keys
CREATE TABLE IF NOT EXISTS post_interactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID, -- Will add foreign key later
    interaction_type VARCHAR(20) CHECK (interaction_type IN ('like', 'save', 'share', 'view')),
    reaction_type VARCHAR(20) DEFAULT 'like',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id, interaction_type)
);

CREATE TABLE IF NOT EXISTS comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID, -- Will add foreign key later
    content TEXT NOT NULL,
    parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    likes_count INTEGER DEFAULT 0,
    is_answer BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_expertise (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID, -- Will add foreign key later
    topic VARCHAR(100) NOT NULL,
    expertise_level INTEGER CHECK (expertise_level BETWEEN 1 AND 5),
    verification_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, topic)
);

CREATE TABLE IF NOT EXISTS feed_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID, -- Will add foreign key later
    preferred_modes JSONB DEFAULT '{"learn": true, "work": true, "connect": true, "chill": true}',
    content_ratio JSONB DEFAULT '{"professional": 70, "personal": 30}',
    noise_filters JSONB DEFAULT '{"humble_bragging": false, "self_promotion": false}',
    notification_settings JSONB DEFAULT '{"likes": true, "comments": true, "mentions": true, "jobs": true}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Add indexes
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_mode ON posts(post_mode);
CREATE INDEX IF NOT EXISTS idx_posts_type ON posts(type);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_post_interactions_post_id ON post_interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_post_interactions_user_id ON post_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_author_id ON comments(author_id);
CREATE INDEX IF NOT EXISTS idx_user_expertise_user_id ON user_expertise(user_id);

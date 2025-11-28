-- Create comments table (simple version without posts dependency)
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id TEXT NOT NULL, -- Using TEXT instead of UUID for now
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    likes_count INTEGER DEFAULT 0,
    is_liked BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_author_id ON public.comments(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_comment_id ON public.comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments(created_at DESC);

-- Create comment_likes table for tracking individual likes
CREATE TABLE IF NOT EXISTS public.comment_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(comment_id, user_id)
);

-- Create index for comment_likes
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON public.comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_id ON public.comment_likes(user_id);

-- Enable RLS (Row Level Security)
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for comments
CREATE POLICY "Users can view all comments" ON public.comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own comments" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own comments" ON public.comments
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own comments" ON public.comments
    FOR DELETE USING (auth.uid() = author_id);

-- Create RLS policies for comment_likes
CREATE POLICY "Users can view all comment likes" ON public.comment_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own comment likes" ON public.comment_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comment likes" ON public.comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update comment likes count
CREATE OR REPLACE FUNCTION public.update_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.comments 
        SET likes_count = likes_count + 1,
            updated_at = NOW()
        WHERE id = NEW.comment_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.comments 
        SET likes_count = likes_count - 1,
            updated_at = NOW()
        WHERE id = OLD.comment_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update likes count
CREATE TRIGGER update_comment_likes_count_trigger
    AFTER INSERT OR DELETE ON public.comment_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_comment_likes_count();

-- Create updated_at trigger for comments
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

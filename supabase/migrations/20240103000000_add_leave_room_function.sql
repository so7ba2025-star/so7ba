-- Create the leave_room function
CREATE OR REPLACE FUNCTION public.leave_room(
  p_user_id text,
  p_room_id text
) 
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_room_record RECORD;
  v_updated_members jsonb;
  v_new_host_id text;
  v_result jsonb;
BEGIN
  -- Get the current room state
  SELECT * INTO v_room_record 
  FROM public.rooms 
  WHERE id = p_room_id
  FOR UPDATE; -- Lock the row for update
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Room not found');
  END IF;
  
  -- Remove the user from members
  v_updated_members := (
    SELECT jsonb_agg(member)
    FROM jsonb_array_elements(v_room_record.members) member
    WHERE (member->>'user_id')::text != p_user_id
  );
  
  -- If no members left, delete the room
  IF v_updated_members IS NULL OR jsonb_array_length(v_updated_members) = 0 THEN
    DELETE FROM public.rooms WHERE id = p_room_id;
    RETURN jsonb_build_object('deleted', true);
  END IF;
  
  -- Check if the leaving user was the host
  IF v_room_record.host_id = p_user_id THEN
    -- Assign new host (first member in the list)
    v_new_host_id := v_updated_members->0->>'user_id';
  ELSE
    v_new_host_id := v_room_record.host_id;
  END IF;
  
  -- Update the room
  UPDATE public.rooms
  SET 
    members = v_updated_members,
    host_id = v_new_host_id,
    updated_at = NOW()
  WHERE id = p_room_id;
  
  -- Return success with the updated members
  RETURN jsonb_build_object(
    'success', true,
    'members', v_updated_members,
    'new_host_id', v_new_host_id
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.leave_room(text, text) TO authenticated;

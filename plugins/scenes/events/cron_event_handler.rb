module AresMUSH
  module Scenes
    class CronEventHandler
      def on_event(event)
        
        config = Global.read_config("scenes", "room_cleanup_cron")
        if Cron.is_cron_match?(config, event.time)
          Global.logger.debug "Empty scene cleanup."
          clear_rooms
        end
        
        config = Global.read_config("scenes", "unshared_scene_cleanup_cron")
        if Cron.is_cron_match?(config, event.time)
           Global.logger.debug "Unshared scenes cleanup."
           delete_unshared_scenes
        end
        
        trending_category = Global.read_config("scenes", "trending_scenes_category")
        if (!trending_category.blank?)
          config = Global.read_config("scenes", "trending_scenes_cron")
          if Cron.is_cron_match?(config, event.time)
             Global.logger.debug "Trending scenes."
             post_trending_scenes
          end
        end
      end
      
      def clear_rooms
        rooms = Room.all.select { |r| !!r.scene_set || !!r.scene || !r.scene_nag}
        
        rooms.each do |r|
          if (r.clients.empty?)
            if (r.scene_set)
              r.update(scene_set: nil)
            end
            
            if (!r.scene_nag)
              r.update(scene_nag: true)
            end
            
            if (should_stop_empty_scene(r))
              Global.logger.debug("Stopping empty scene in #{r.name}")
              Scenes.stop_scene(r.scene, Game.master.system_character)
            end
          end
        end
      end
      
      def delete_unshared_scenes
        # Completed scenes that haven't been shared are marked for deletion after a few days.

        delete_unshared = Global.read_config("scenes", "delete_unshared_scenes")
        warn_days = Global.read_config('scenes', 'unshared_scene_warning_days')
        
        Scene.all.select { |s| s.completed && !s.shared }.each do |scene|
          if (scene.in_trash)
            if (Time.now > scene.trash_date)
              Global.logger.info "Deleting scene #{scene.id}"
              scene.delete
            end
          elsif delete_unshared
            elapsed_days = scene.days_since_last_activity
            if (elapsed_days > warn_days)
              Scenes.move_to_trash(scene, Game.master.system_character)
            end
          end
        end
      end
      
      def should_stop_empty_scene(room)
        scene = room.scene
        return false if !scene
        return true if !scene.temp_room
        
        last_activity = scene.last_activity || Time.now
        idle_timeout = Global.read_config("scenes", "idle_scene_timeout_days")
        elapsed_days = (Time.now - last_activity) / 86400
        return (elapsed_days >= idle_timeout)
      end
      
      def post_trending_scenes
        recent_scenes = Scene.all.select { |s| s.likes > 0 && (Time.now - (s.date_shared || s.created_at) < 864000) }
        trending = recent_scenes.sort_by { |s| -s.likes }[0, 10]
        
        return if trending.count < 1
        
        template = TrendingScenesTemplate.new(trending)
        post = template.render
        
        Forum.system_post(
          Global.read_config("scenes", "trending_scenes_category"),
          t('scenes.trending_scenes_subject'), 
          post)
      end
    end
  end
end

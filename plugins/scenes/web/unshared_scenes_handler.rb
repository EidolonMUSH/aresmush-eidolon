module AresMUSH
  module Scenes
    class UnsharedScenesRequestHandler
      def handle(request)
        enactor = request.enactor
        
        error = Website.check_login(request)
        return error if error
                
        scenes = []
        AresCentral.play_screen_alts(enactor).each do |alt|
          scenes.concat alt.unshared_scenes
        end
        
        unshared = scenes.uniq.sort_by { |s| s.id.to_i }.reverse.map { |s| {
             title: s.title.blank? ? nil : s.date_title, 
             icdate: s.icdate,
             summary: s.summary.blank? ? nil : Website.format_markdown_for_html(s.summary),
             is_private: s.private_scene,
             participants: s.participants
                 .to_a
                 .sort_by { |p| p.name }
                 .map { |p| { 
                    name: p.name,
                    nick: p.nick,
                    id: p.id, 
                    icon: Website.icon_for_char(p)
                  }},
             id: s.id,
             location: s.location.blank? ? nil : s.location,
             scene_type: s.scene_type ? s.scene_type.titlecase : 'Unknown',
             scene_pacing: s.scene_pacing,
             updated: OOCTime.local_long_timestr(enactor, s.last_activity),
             last_posed: s.last_posed ? s.last_posed.name : nil,
             can_edit: Scenes.can_edit_scene?(enactor, s),
             can_share: s.completed && !s.location.blank? && !s.summary.blank? && !s.title.blank?,
             last_pose_time_str: s.last_pose_time_str(enactor),
             in_trash: s.in_trash,
             trash_date: OOCTime.local_long_timestr(enactor, s.trash_date),
             content_warning: s.content_warning
             

            }}

        {
          unshared: unshared,
          unshared_warning_days: Global.read_config('scenes', 'unshared_scene_warning_days'),
          delete_unshared: Global.read_config('scenes', 'delete_unshared_scenes')
        }
  
      end
    end
  end
end
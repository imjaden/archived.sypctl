require 'active_record'

desc 'comment data migrate to notification'
task comment_to_notification: :environment do
  Comment.where(obj_type: 6).each do |comment|
    Notification.create(
      title: comment.obj_title,
      content: comment.content,
      creater_id: comment.user_id,
      created_at: comment.created_at,
      updated_at: comment.updated_at,
      published: true
    )
  end
end

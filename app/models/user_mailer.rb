class UserMailer < ActionMailer::Base
  include ActionController::UrlWriter
  helper :application
  
  def invitation(invitation)
    subject       "[#{ArchiveConfig.APP_NAME}] Invitation"
    recipients    invitation.invitee_email
    from            ArchiveConfig.RETURN_ADDRESS
    sent_on       Time.now
    content_type  "text/html"
    body          :invitation => invitation, :user_name => (invitation.creator.is_a?(User) ? invitation.creator.login : ''), :host => ArchiveConfig.APP_URL.gsub(/http:\/\//, '')
  end
  
  def invitation_to_claim(invitation, archivist)
    subject       "[#{ArchiveConfig.APP_NAME}] Invitation To Claim Stories"
    recipients    invitation.invitee_email
    from          ArchiveConfig.RETURN_ADDRESS
    sent_on       Time.now
    content_type  "text/html"
    body          :invitation => invitation, :external_author => invitation.external_author, :archivist => archivist, :host => ArchiveConfig.APP_URL.gsub(/http:\/\//, '')
  end
  
  def claim_notification(external_author, claimed_works)
    subject       "[#{ArchiveConfig.APP_NAME}] Stories Uploaded"
    recipients    external_author.user.email
    from          ArchiveConfig.RETURN_ADDRESS
    sent_on       Time.now
    content_type  "text/html"
    body          :external_author => external_author, :claimed_works => claimed_works, :host => ArchiveConfig.APP_URL.gsub(/http:\/\//, '')
  end

  def invite_increase_notification(user, total)
    setup_email(user)
    @subject    += 'New Invitations'  
    @body[:total] = total 
  end

  def archive_notification(admin, user, subject, message)
    setup_email(user)
    @subject = "[#{ArchiveConfig.APP_NAME}] Admin Message #{subject}"
    @body[:message] = message
    @body[:admin] = admin
  end

  def signup_notification(user)
    setup_email(user)
    @subject    += 'Please activate your new account' 
    @body[:url] += "/activate/#{user.activation_code}"  
  end
   
  def activation(user)
    setup_email(user)
    @subject += 'Your account has been activated.'
  end 
   
  def reset_password(user)
    setup_email(user)
    @subject    += 'Password reset'
  end
   
  # Sends email to an owner of the top-level commentable when a new comment is created
  def comment_notification(user, comment)
    setup_email(user)
    @subject += "New comment on " + comment.ultimate_parent.commentable_name
    @body[:commentable] = comment.ultimate_parent     
    @body[:comment] = comment
  end

  # Sends email to an owner of the top-level commentable when a comment is edited
  def edited_comment_notification(user, comment)
    setup_email(user)
    @subject += "Edited comment on " + comment.ultimate_parent.commentable_name
    @body[:commentable] = comment.ultimate_parent     
    @body[:comment] = comment
  end

  # Sends email to comment creator when a reply is posted to their comment
  # This may be a non-user of the archive
  def comment_reply_notification(old_comment, new_comment)
    setup_comment_email(old_comment)
    @subject += "Reply to your comment on " + old_comment.ultimate_parent.commentable_name     
    @body[:comment] = new_comment
  end
   
  # Sends email to comment creator when a reply to their comment is edited
  # This may be a non-user of the archive
  def edited_comment_reply_notification(old_comment, edited_comment)
    setup_comment_email(old_comment)
    @subject += "Edited reply to your comment on " + old_comment.ultimate_parent.commentable_name     
    @body[:comment] = edited_comment
  end

   # Sends email to the poster of a comment 
  def comment_sent_notification(comment)
    setup_comment_email(comment)
    @subject += "Comment you sent on " + comment.ultimate_parent.commentable_name
    @body[:comment] = comment
  end
   
  # Sends email when a user is added as a co-author
  def coauthor_notification(user, work)
    setup_email(user)
    @subject    += "Co-Author Notification"
    @body[:work] = work
  end 
   
  # Sends emails to authors whose stories were listed as the inspiration of another work
  def related_work_notification(user, related_work)
    setup_email(user)
    @subject    += "Related work notification"
    @body[:related_work] = related_work
  end
   
  # Sends email to authors when a work is edited
  def edit_work_notification(user, work)
    setup_email(user)
    @subject    += "Your story has been updated"
    @body[:work] = work
  end
   
  # Sends email to authors when a creation is deleted
  def delete_work_notification(user, work)
    setup_email(user)
    @content_type = "multipart/mixed"
    @subject    += "Your story has been deleted"
    @body[:work] = work

    part :content_type => "text/html", :body => render_message("delete_work_notification.html", :work => work)  
    
    work_copy = generate_attachment_from_work(work)
    part :content_type => "multipart/mixed" do |p|
      p.attachment :content_type => "text/plain", :filename => work.title.gsub(/[*:?<>|\/\\\"]/,'') + ".txt", :body => work_copy
      p.attachment :content_type => "text/plain", :filename => work.title.gsub(/[*:?<>|\/\\\"]/,'') + ".html", :body => work_copy
    end
  end
  
  def feedback(feedback)
    setup_email_without_name(feedback.email)
    @subject = "#{ArchiveConfig.APP_NAME}: Support - " + feedback.summary
    @body[:summary] = feedback.summary
    @body[:comment] = feedback.comment
  end  

  def abuse_report(report)
     setup_email_without_name(report.email)
     @recipients = report.email
     @subject += "Your abuse report"
     @body = {:url => report.url, :comment => report.comment}
  end

  def generate_attachment_from_work(work)
    attachment_string =  "Title: " + work.title + "<br />" + "by " + work.pseuds.collect(&:name).join(", ") + "<br />\n"
    attachment_string += "<br/>Tags: " + work.tags.collect(&:name).join(", ") + "<br/>\n" unless work.tags.blank?
    attachment_string += "<br/>Summary: " + work.summary + "<br/>\n" unless work.summary.blank?
    attachment_string += "<br/>Notes: " + work.notes + "<br/>\n" unless work.notes.blank?
    attachment_string += "<br/>End Notes: " + work.endnotes + "<br/>\n" unless work.endnotes.blank?
    attachment_string += "<br/>Published at: " + work.first_chapter.published_at.to_s + "<br/>\n" unless work.first_chapter.published_at.blank?
    attachment_string += "Revised at: " + work.revised_at.to_s + "<br/>\n" unless work.revised_at.blank?

    work.chapters.each do |chapter|
      attachment_string += "<br/>Chapter " + chapter.position.to_s unless !work.chaptered?
      attachment_string += ": " + chapter.title unless chapter.title.blank?
      attachment_string += "\n<br/>by: " + chapter.pseuds.collect(&:name).join(", ") + "<br />\n" unless chapter.pseuds.sort == work.pseuds.sort
      attachment_string += "<br/>Summary: " + chapter.summary + "<br/>\n" unless chapter.summary.blank?
      attachment_string += "<br/>Notes: " + chapter.notes + "<br/>\n" unless chapter.notes.blank?
      attachment_string += "<br/>End Notes: " + chapter.endnotes + "<br/>\n" unless chapter.endnotes.blank?
      attachment_string += "<br/>" + chapter.content + "<br />\n"
    end
    return attachment_string
  end
  
  protected
   
    def setup_email(user)
      setup_email_attributes
      @recipients  = "#{user.email}"
      @body[:user] = user
      @body[:name] = user.login
    end
     
    def setup_email_to_nonuser(email, name)
      setup_email_attributes
      @recipients = email
      @body[:name] = name
    end
    
    def setup_email_without_name(email)
      setup_email_attributes
      @recipients = email     
    end
     
    def setup_email_attributes
      @from        = ArchiveConfig.RETURN_ADDRESS
      @subject     = "[#{ArchiveConfig.APP_NAME}] "
      @sent_on     = Time.now
      @body[:url]  = ArchiveConfig.APP_URL
      @body[:host] = ArchiveConfig.APP_URL.gsub(/http:\/\//, '')
      @content_type = "text/html"
    end
     
    def setup_comment_email(comment)
      setup_email_to_nonuser(comment.comment_owner_email, comment.comment_owner_name)
      @body[:commentable] = comment.ultimate_parent
    end
         
end

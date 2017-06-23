class FillinAuthWithGithub < ActiveRecord::Migration[5.0]
  def change
    User.update_all(auth: 'github')
  end
end

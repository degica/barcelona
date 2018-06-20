class FillinModeEnvVars < ActiveRecord::Migration[5.1]
  def change
    EnvVar.all.each do |e|
      e.mode = (e.secret?) ? "legacy_secret" : "plain"
      e.save!
    end
  end
end

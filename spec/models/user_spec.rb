require 'rails_helper'

describe User do
  describe ".login!" do
    subject { User.login!("github_token") }

    let(:github_client) do
      double(user_teams: github_teams, user: double(login: "k2nr"))
    end

    context "when teams are specified" do
      before do
        allow(Octokit::Client).to receive(:new) { github_client }
        allow(ENV).to receive(:[]).with('GITHUB_ORGANIZATION') { 'degica' }
        allow(ENV).to receive(:[]).with('GITHUB_DEVELOPER_TEAM') { 'developers' }
        allow(ENV).to receive(:[]).with('GITHUB_ADMIN_TEAM') { 'Admin developers' }
        allow(ENV).to receive(:[]).with('ENCRYPTION_KEY') { 'encryption' }
      end

      context "when a user belongs to a github admin team" do
        let(:github_teams) do
          [
            double(name: "Admin developers", organization: double(login: "degica"))
          ]
        end
        its(:roles) { is_expected.to eq ["admin"] }
        its(:token) { is_expected.to be_present }
      end

      context "when a user belongs to a github developers team" do
        let(:github_teams) do
          [
            double(name: "developers", organization: double(login: "degica"))
          ]
        end
        its(:roles) { is_expected.to eq ["developer"] }
        its(:token) { is_expected.to be_present }
      end

      context "when a user doesn't belong to allowed github teams" do
        let(:github_teams) do
          [
            double(name: "reviewers", organization: double(login: "degica"))
          ]
        end

        it "raises an error" do
          expect{subject}.to raise_error ExceptionHandler::Unauthorized
        end
      end

      context "when a user doesn't belong to the organization" do
        let(:github_teams) do
          [
            double(name: "Admin developers", organization: double(login: "other_org"))
          ]
        end

        it "raises an error" do
          expect{subject}.to raise_error ExceptionHandler::Unauthorized
        end
      end
    end

    context "when teams are not specified" do
      before do
        allow(Octokit::Client).to receive(:new) { github_client }
        allow(ENV).to receive(:[]).with('GITHUB_ORGANIZATION') { 'degica' }
        allow(ENV).to receive(:[]).with('GITHUB_DEVELOPER_TEAM') { nil }
        allow(ENV).to receive(:[]).with('GITHUB_ADMIN_TEAM') { nil }
        allow(ENV).to receive(:[]).with('ENCRYPTION_KEY') { 'encryption' }
      end

      let(:github_teams) do
        [
          double(name: "reviewers",  organization: double(login: "degica")),
          double(name: "developers", organization: double(login: "degica"))
        ]
      end

      its(:roles) { is_expected.to eq ["developer", "admin"] }
      its(:token) { is_expected.to be_present }

      context "when a user doesn't belong to the organization" do
        let(:github_teams) do
          [
            double(name: "Admin developers", organization: double(login: "other_org"))
          ]
        end

        it "raises an error" do
          expect{subject}.to raise_error ExceptionHandler::Unauthorized
        end
      end
    end
  end
end

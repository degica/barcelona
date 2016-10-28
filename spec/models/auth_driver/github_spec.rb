require "rails_helper"

describe AuthDriver::Github do
  describe ".login!" do
    subject { described_class.new("github_token").login! }

    before do
      allow(Octokit::Client).to receive(:new) { github_client }
    end

    let(:github_client) do
      double(user: double(login: "k2nr"), organizations: [double(login: 'degica')])
    end

    context "when a user belongs to the github organization" do
      before do
        ENV['GITHUB_ORGANIZATION'] = 'degica'
      end
      its(:token) { is_expected.to be_present }
    end

    context "when a user doesn't belong to the github organization" do
      before do
        ENV['GITHUB_ORGANIZATION'] = 'other_org'
      end
      it "raises an error" do
        expect{subject}.to raise_error ExceptionHandler::Unauthorized
      end
    end
  end
end

require "spec_helper"
require_relative "mocks/client_response"
require_relative "mocks/response_mapping"
require_relative "mocks/rest_client"
require "nokogiri/diff"

describe VCloudSdk::VDC do

  let(:logger) { VCloudSdk::Test.logger }
  let(:url) { VCloudSdk::Test::Response::URL }
  let(:disk_name) { VCloudSdk::Test::Response::INDY_DISK_NAME }
  let(:vdc_link) { VCloudSdk::Test::Response::VDC_LINK }

  subject do
    session = VCloudSdk::Test.mock_session(logger, url)
    described_class.new(session, vdc_link)
  end

  describe "#storage_profiles" do
    context "vdc has storage profiles" do
      before do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :non_empty
      end

      context "vdc name contains no space" do
        it "returns array of VdcStorageProfile object" do
          storage_profiles = subject.storage_profiles
          storage_profiles.should have(1).item
          storage_profiles.first.should be_an_instance_of VCloudSdk::VdcStorageProfile
        end
      end

      context "vdc name contains spaces" do
        before do
          subject.instance_variable_set(:@name, VCloudSdk::Test::Response::OVDC_NAME_WITH_SPACE)
        end

        it "returns array of VdcStorageProfile object" do
          storage_profiles = subject.storage_profiles
          storage_profiles.should have(1).item
          storage_profiles.first.should be_an_instance_of VCloudSdk::VdcStorageProfile
        end
      end
    end

    context "vdc has no storage profile" do
      before do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :empty
      end

      its(:storage_profiles) { should eql [] }
    end
  end

  describe "#list_storage_profiles" do
    context "vdc has storage profiles" do
      before do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :non_empty
      end

      its(:list_storage_profiles) { should eql [VCloudSdk::Test::Response::STORAGE_PROFILE_NAME] }
    end

    context "vdc has no storage profile" do
      before do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :empty
      end

      its(:storage_profiles) { should eql [] }
    end
  end

  describe "#find_storage_profile_by_name" do
    context "storage profile with given name exists" do
      it "return a storage profile given targeted name" do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :non_empty
        storage_profile = subject
                            .find_storage_profile_by_name(VCloudSdk::Test::Response::STORAGE_PROFILE_NAME)
        storage_profile.name.should eql VCloudSdk::Test::Response::STORAGE_PROFILE_NAME
      end
    end

    context "storage profile with given name does not exist" do
      it "raises ObjectNotFoundError" do
        VCloudSdk::Test::ResponseMapping.set_option storage_profile: :non_empty
        expect do
          subject.find_storage_profile_by_name("xxx")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Storage profile 'xxx' is not found"
      end
    end
  end

  describe "storage_profile_exists?" do
    before do
      VCloudSdk::Test::ResponseMapping.set_option storage_profile: :non_empty
    end

    context "storage profile with matching name exists" do
      it "returns true" do
        subject.storage_profile_exists?(VCloudSdk::Test::Response::STORAGE_PROFILE_NAME)
          .should be_true
      end
    end

    context "storage profile with matching name does not exist" do
      it "returns false" do
        subject.storage_profile_exists?("xxx").should be_false
      end
    end
  end

  describe "#vapps" do
    context "vdc has vapps" do
      it "returns array of VApp objects" do
        subject.vapps.should have(1).item
        subject.vapps.first.should be_an_instance_of VCloudSdk::VApp
      end
    end

    context "vdc has no vapps" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns empty array" do
        subject.vapps.should eql []
      end
    end

  end

  describe "#list_vapps" do
    context "vdc has vapps" do
      it "returns a collection of vapp names" do
        vapp_names = subject.list_vapps
        vapp_names.should eql([VCloudSdk::Test::Response::VAPP_NAME])
      end
    end

    context "vdc has no vapp" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns empty array" do
        subject.list_vapps.should eql []
      end
    end
  end

  describe "#find_vapp_by_name" do
    before do
      VCloudSdk::Test::ResponseMapping.set_option vapp_power_state: :on
    end

    context "vapp with given name exists" do
      it "returns a vapp given targeted name" do
        vapp = subject.find_vapp_by_name(VCloudSdk::Test::Response::VAPP_NAME)
        vapp.name.should eql VCloudSdk::Test::Response::VAPP_NAME
      end
    end

    context "vapp with given name does not exist" do
      it "raises ObjectNotFoundError" do
        expect do
          subject.find_vapp_by_name("xxxx")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "VApp 'xxxx' is not found"
      end
    end
  end

  describe "vapp_exists?" do
    before do
      VCloudSdk::Test::ResponseMapping.set_option vapp_power_state: :on
    end

    context "vapp with matching name exists" do
      it "returns true" do
        subject.vapp_exists?(VCloudSdk::Test::Response::VAPP_NAME).should be_true
      end
    end

    context "vapp with matching name does not exist" do
      it "returns false" do
        subject.vapp_exists?("xxx").should be_false
      end
    end
  end

  describe "#resources" do
    context "Cpu clock speed limit is greater than 0" do
      it "returns limit - used" do
        subject.resources.cpu.available_cores.should eq 4
      end
    end

    context "Cpu clock speed limit is 0" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns -1" do
        subject.resources.cpu.available_cores.should eq(-1)
      end
    end

    context "Memory limit is greater than 0" do
      it "returns limit - used" do
        subject.resources.memory.available_mb.should eq 4096
      end
    end

    context "limit cpu clock speed is 0" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns -1" do
        subject.resources.memory.available_mb.should eq(-1)
      end
    end
  end

  describe "#networks" do
    it "returns array of Network objects" do
      networks = subject.networks
      networks.should have(2).items
      networks.each do |network|
        network.should be_an_instance_of VCloudSdk::Network
      end
    end
  end

  describe "#list_networks" do
    context "vdc has networks" do
      it "returns a collection of network names" do
        network_names = subject.list_networks
        network_names.should eql(["164-935-default-isolated",
                                  VCloudSdk::Test::Response::ORG_NETWORK_NAME])
      end
    end
  end

  describe "#find_network_by_name" do
    context "network with given name exists" do
      it "returns a network given targeted name" do
        network = subject
                    .find_network_by_name(
                      VCloudSdk::Test::Response::ORG_NETWORK_NAME)
        network.name.should eql VCloudSdk::Test::Response::ORG_NETWORK_NAME
      end
    end

    context "network with given name does not exist" do
      it "raises ObjectNotFoundError" do
        expect do
          subject
            .find_network_by_name("xxx")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Network 'xxx' is not found"
      end
    end
  end

  describe "#network_exists?" do
    context "network with matching name exists" do
      it "returns true" do
        subject.network_exists?(VCloudSdk::Test::Response::ORG_NETWORK_NAME).should be_true
      end
    end

    context "network with matching name does not exist" do
      it "returns false" do
        subject.network_exists?("xxx").should be_false
      end
    end
  end

  describe "#disks" do
    context "vdc has disks" do
      it "returns a collection of disks" do
        disks = subject.disks
        disks.should have(1).item
        disk = disks[0]
        disk.should be_an_instance_of VCloudSdk::Disk
        disk.name.should eql disk_name
      end
    end

    context "vdc has no disk" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns empty array" do
        subject.disks.should eql []
      end
    end
  end

  describe "#list_disks" do
    context "vdc has disks" do
      it "returns a collection of disk names" do
        disk_names = subject.list_disks
        disk_names.should eql [disk_name]
      end
    end

    context "vdc has no disk" do
      let(:vdc_link) { VCloudSdk::Test::Response::EMPTY_VDC_LINK }

      it "returns empty array" do
        subject.list_disks.should eql []
      end
    end
  end

  describe "#find_disks_by_name" do
    context "there is one disk with given name" do
      it "returns array containing one disk" do
        disks = subject.find_disks_by_name(disk_name)
        disks.should have(1).item
        disk = disks[0]
        disk.should be_an_instance_of VCloudSdk::Disk
        disk.name.should eql disk_name
      end
    end

    context "there are two disks with given name" do
      let(:vdc_link) { VCloudSdk::Test::Response::VDC_WITH_TWO_DISKS_LINK }
      it "returns array containing two disks" do
        disks = subject.find_disks_by_name(disk_name)
        disks.should have(2).item
        disks.each do |disk|
          disk.should be_an_instance_of VCloudSdk::Disk
          disk.name.should eql disk_name
        end
      end
    end

    context "targeted disk with given name does not exist" do
      it "raises an error" do
        expect do
          subject.find_disks_by_name("xxxx")
        end.to raise_exception VCloudSdk::ObjectNotFoundError
        "Disk 'xxxx' is not found"
      end
    end
  end

  describe "#disk_exists?" do
    context "disk with matching name exists" do
      it "returns true" do
        subject.disk_exists?(disk_name).should be_true
      end
    end

    context "disk with matching name does not exist" do
      it "returns false" do
        subject.disk_exists?("xxx").should be_false
      end
    end
  end

  describe "#create_disk" do
    let(:disk_name_to_create) { disk_name }

    context "input parameter size is negative" do
      it "raises an exception" do
        expect do
          subject.create_disk(disk_name_to_create, -1)
        end.to raise_exception VCloudSdk::CloudError,
                               "Invalid size in MB -1"
      end
    end

    context "error occurs when creating disk" do
      it "raises the exception" do
        subject
          .send(:connection)
          .stub(:post)
          .with(anything, anything, VCloudSdk::Xml::MEDIA_TYPE[:DISK_CREATE_PARAMS])
          .and_raise RestClient::BadRequest

        expect do
          subject.create_disk(disk_name_to_create, 100)
        end.to raise_exception RestClient::BadRequest
      end
    end

    context "create disk without vm locality" do
      it "creates an independent disk successfully" do
        disk = subject.create_disk(disk_name_to_create, 100)
        disk.should be_an_instance_of VCloudSdk::Disk
      end

      context "bus_type and bus_sub_type are specified" do
        it "creates an independent disk successfully" do
          disk = subject.create_disk(disk_name_to_create,
                                     100,
                                     nil,
                                     "scsi",
                                     "lsilogic")
          disk.should be_an_instance_of VCloudSdk::Disk
        end
      end

      context "bus_type specified is invalid" do
        it "raises an error" do
          expect do
            subject.create_disk(disk_name_to_create, 100, nil, "xxx")
          end.to raise_exception VCloudSdk::CloudError,
                                 "Invalid bus type!"
        end
      end

      context "bus_sub_type specified is invalid" do
        it "raises an error" do
          expect do
            subject.create_disk(disk_name_to_create, 100, nil, "scsi", "xxx")
          end.to raise_exception VCloudSdk::CloudError,
                                 "Invalid bus sub type!"
        end
      end
    end

    context "create disk with vm locality" do
      let(:vdc_response) do
        VCloudSdk::Xml::WrapperFactory.wrap_document(
            VCloudSdk::Test::Response::VDC_RESPONSE)
      end

      it "creates an independent disk successfully" do
        VCloudSdk::Test::ResponseMapping.set_option vapp_power_state: :off
        vapp = VCloudSdk::VApp.new(VCloudSdk::Test.mock_session(logger, url),
                                   vdc_response.vapps.first)
        vm = vapp.vms.first
        disk = subject.create_disk(disk_name_to_create, 100, vm)
        disk.should be_an_instance_of VCloudSdk::Disk
      end
    end
  end

  describe "#delete_disk_by_name" do
    context "disk matching the name does not exist" do
      it "raises ObjectNotFoundError" do
        expect do
          subject.delete_disk_by_name("dummy")
        end.to raise_exception VCloudSdk::ObjectNotFoundError,
                               "Disk 'dummy' is not found"
      end
    end

    context "more than one disks matching the name exist" do
      it "raises CloudError" do
        subject
          .should_receive(:find_disks_by_name)
          .with(disk_name)
          .and_return [double("disk 1"), double("disk 2")]

        expect do
          subject.delete_disk_by_name(disk_name)
        end.to raise_exception VCloudSdk::CloudError,
                               "2 disks with name indy_disk_1 were found"
      end
    end

    context "disk is not attached to VM" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option disk_state: :not_attached
      end

      it "deletes the disk successfully" do
        subject
          .send(:connection)
          .should_receive(:delete)
          .with(VCloudSdk::Test::Response::INDY_DISK_URL)
          .and_call_original
        result = subject.delete_disk_by_name(disk_name)
        result.should be_an_instance_of(VCloudSdk::VDC)
      end

      context "error occurs when deleting disk" do
        it "raises the exception" do
          subject
            .should_receive(:delete_single_disk)
            .and_raise RestClient::BadRequest

          expect do
            subject.delete_disk_by_name(disk_name)
          end.to raise_exception RestClient::BadRequest
        end
      end
    end

    context "disk is attached to VM" do
      it "raises an error" do
        VCloudSdk::Test::ResponseMapping
          .set_option disk_state: :attached
        expect do
          subject.delete_disk_by_name(disk_name)
        end.to raise_exception VCloudSdk::CloudError,
                               "Disk '#{disk_name}', link " +
                                 "#{VCloudSdk::Test::Response::INDY_DISK_URL}" +
                                 " is attached to VM '#{VCloudSdk::Test::Response::VM_NAME}'"
      end
    end
  end

  describe "#delete_all_disks_by_name" do
    context "one disk matching the name exists" do
      before do
        VCloudSdk::Test::ResponseMapping
        .set_option disk_state: :not_attached
      end

      it "deletes the disk successfully" do
        subject
          .send(:connection)
          .should_receive(:delete)
          .with(VCloudSdk::Test::Response::INDY_DISK_URL)
          .and_call_original
        result = subject.delete_all_disks_by_name(disk_name)
        result.should be_an_instance_of(VCloudSdk::VDC)
      end

      context "error occurs when deleting disk" do
        it "raises an exception" do
          subject
            .should_receive(:delete_single_disk)
            .and_raise RestClient::BadRequest

          expect do
            subject.delete_all_disks_by_name(disk_name)
          end.to raise_exception "Failed to delete one or more of the disks with name '#{disk_name}'. Check logs for details."
        end
      end
    end

    context "two disks matching the name exist" do
      before do
        VCloudSdk::Test::ResponseMapping
          .set_option disk_state: :not_attached
      end

      it "deletes the disks successfully" do
        subject
          .should_receive(:find_disks_by_name)
          .with(disk_name)
          .and_return [double("disk 1"), double("disk 2")]
        subject
          .should_receive(:delete_single_disk)
          .twice

        result = subject.delete_all_disks_by_name(disk_name)
        result.should be_an_instance_of(VCloudSdk::VDC)
      end

      context "error occurs when deleting disks" do
        it "raises an exception" do
          subject
            .should_receive(:find_disks_by_name)
            .with(disk_name)
            .and_return [double("disk 1"), double("disk 2")]
          subject
            .should_receive(:delete_single_disk)
            .twice
            .and_raise RestClient::BadRequest

          expect do
            subject.delete_all_disks_by_name(disk_name)
          end.to raise_exception "Failed to delete one or more of the disks with name '#{disk_name}'. Check logs for details."
        end
      end
    end
  end

  describe "#edge_gateways" do
    context "vdc has edge gateways" do
      it "returns a collection of edge gateways" do
        edge_gateways = subject.edge_gateways
        edge_gateways.should have(1).item
        edge_gateway = edge_gateways.first
        edge_gateway.should be_an_instance_of VCloudSdk::EdgeGateway
        edge_gateway.name.should eql "164-935"
      end

      context "there are no edge gateways" do
        it "returns empty array" do
          VCloudSdk::Xml::QueryResultRecords
            .any_instance
            .stub(:edge_gateway_records)
            .and_return []
          edge_gateways = subject.edge_gateways
          edge_gateways.should be_empty
        end
      end
    end
  end
end

#
# Cookbook Name:: new_mongo_depo
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
Name = data_bag_item("mongo", "new_depo")["name"]
Type = data_bag_item("mongo", "new_depo")["type"]
Instances = data_bag_item("mongo", "new_depo")["instances"]
NodeIp = node.automatic["ipaddress"]
MongoDir = "/home/dhcd/mongo"
Chef::Log.warn(Name)
Chef::Log.warn(Type)
Chef::Log.warn(Instances)
Chef::Log.warn(File.exists?("/home/dhcd/bin"))
#mongo没有初始化，中止程序
if !File.exists?("/home/dhcd/bin")
    exit
end
for i in 0..(Instances.length-1)
    Chef::Log.warn("ip: " << Instances[i]["host"])
    Chef::Log.warn("now ip: #{NodeIp}")
    Chef::Log.warn(i)
    check = 0
    if Instances[i]["host"] == NodeIp
        instance = Instances[i]
        directory "#{MongoDir}/#{Name}" do
            action :create
            not_if{File.exists?("#{MongoDir}/#{Name}")}
        end

        Chef::Log.warn(instance)
        if Type == "standalone"
            if File.exists?("#{MongoDir}/#{Name}/data")
                next
            end

            directory "#{MongoDir}/#{Name}/data" do
                action :create
            end

            directory "#{MongoDir}/#{Name}/log" do
                action :create
            end

            template "#{MongoDir}/#{Name}/#{Name}.config" do
                source node["mongo"][Type]["config"]
                variables(:Name=>Name,:Ip=>NodeIp,:Port=>instance["port"])
            end

            bash "start mongo" do
                code "/home/dhcd/bin/mongod --config #{MongoDir}/#{Name}/#{Name}.config"
                retries 0
                not_if{File.exists?("#{MongoDir}/#{Name}/data/mongod.lock")}
            end
            check = 1
        else
            instance_path = "#{MongoDir}/#{Name}/#{instance["name"]}"
            Chef::Log.warn(instance_path)

            if File.exists?(instance_path)
                next
            end

            directory instance_path do
                action :create
            end

            directory "#{instance_path}/data" do
                action :create
            end

            directory "#{instance_path}/log" do
                action :create
            end

            if instance["type"] == "mongos"
                configdbs = ""
                flag = 0
                for j in 0..(Instances.length-1)
                    if Instances[j]["type"] == "configdb"
                        if flag == 0
                            configdbs << Instances[j]["host"] + ":" + Instances[j]["port"].to_s()
                            flag = 1
                        else
                            configdbs << ","+Instances[j]["host"] + ":" + Instances[j]["port"].to_s()
                        end
                    end
                end
                Chef::Log.warn(configdbs)
                template "#{instance_path}/#{instance["name"]}.config" do
                    source node["mongo"][instance["type"]]["config"]
                    variables(:configdbs=>configdbs,:ParentName=>Name,:Name=>instance["name"],:Ip=>NodeIp,:Port=>instance["port"])
                end
                execute "start mongo" do
                    command "/home/dhcd/bin/mongos --config #{instance_path}/#{instance["name"]}.config"
                end
            else
                template "#{instance_path}/#{instance["name"]}.config" do
                    source node["mongo"][instance["type"]]["config"]
                    variables(:ParentName=>Name,:Name=>instance["name"],:Ip=>NodeIp,:Port=>instance["port"])
                end
                execute "start mongo" do
                    command "/home/dhcd/bin/mongod --config #{instance_path}/#{instance["name"]}.config"
                end
            end
        end
    end
end

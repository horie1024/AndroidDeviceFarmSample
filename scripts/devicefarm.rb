require 'aws-sdk'
require 'json'
require 'net/http'

def upload(s3_url, file_path)
    url = URI.parse(s3_url)
    apk_contents = File.open(file_path, "rb").read
    Net::HTTP.start(url.host) do |http| 
        http.send_request("PUT", url.request_uri, apk_contents, {"content-type" => "application/octet-stream"}) 
    end
end

project_arn = ENV['PROJECT_ARN']
slack_webhook_url = ENV['SLACK_WEB_HOOK_URL']

devicefarm = Aws::DeviceFarm::Client.new(
    region: 'us-west-2',
    credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
)

list_device_pools_resp = devicefarm.list_device_pools({
    arn: project_arn
})

upload_apk_resp = devicefarm.create_upload({
    project_arn: project_arn,
    name: "app-debug.apk",
    type: "ANDROID_APP",
    content_type: "application/octet-stream"
})

s3_url = upload_apk_resp.upload.url
upload(s3_url, "app/build/outputs/apk/app-debug.apk")

upload_calabash_test_resp = devicefarm.create_upload({
    project_arn: project_arn,
    name: "features.zip",
    type: "CALABASH_TEST_PACKAGE",
    content_type: "application/octet-stream"
})

calabash_s3_url = upload_calabash_test_resp.upload.url
upload(calabash_s3_url, "features.zip")

10.times do
    res_apk_upload = devicefarm.get_upload({
        arn: upload_apk_resp.upload.arn
    })

    res_test_upload = devicefarm.get_upload({
        arn: upload_calabash_test_resp.upload.arn 
    })

    if res_apk_upload.upload.status == "SUCCEEDED" && 
        res_test_upload.upload.status == "SUCCEEDED"

        schedule_run_resp = devicefarm.schedule_run({
            project_arn: project_arn,
            app_arn: upload_apk_resp.upload.arn,
            device_pool_arn: list_device_pools_resp.device_pools[0].arn,
            test: {
                type: 'CALABASH',
                test_package_arn: upload_calabash_test_resp.upload.arn
            }
        })

        uri = URI.parse(slack_webhook_url)
        data = {"text" => "@vasilybot " + schedule_run_resp.run.arn}
        Net::HTTP.post_form(uri, {"payload" => data.to_json})

        exit
    end

    sleep(1)
end


## Backup for 酷盘 (kanbox.com)

此 Gem 是 [Backup](https://github.com/meskyanichi/backup) 的辅助插件，目的是让 Backup 支持存储到 [酷盘](http://www.kanbox.com)。

## 安装

```bash
$ gem install backup-kanbox
```
## 配置

你需要在你的 Backup models 文件里面单独引用 `backup-kanbox`，比如：

~/Backup/models/foo.rb

```ruby
require "backup-kanbox" # 引用 backup-kanbox

Backup::Model.new(:kanbox_foo, 'Description for foo') do

  # 备份存储方式, 注意，Kanbox 这个地方需要引号
  store_with "Kanbox" do |config|
    # 开发者帐号申请: http://open.kanbox.com
    config.api_key = 'api key'
    config.api_secret = 'api secret'
    config.path = '/path/to/my/backups'
    config.keep = 10
  end
end
```

然后你就可以用 Backup 把你的备份文件存储到酷盘里面了。

至于 Backup 的使用方法请参见 [Backup](https://github.com/meskyanichi/backup) 的文档。

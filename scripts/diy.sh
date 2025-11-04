# 修改默认IP & 固件名称 & 编译署名
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='WRT'/g" package/base-files/files/bin/config_generate
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Built by Mary')/g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# 调整在Argon主题下，概览页面显示/隐藏按钮的样式
sed -i '/^\.td\.cbi-section-actions {$/,/^}$/ {
    /^}$/a\
.cbi-section.fade-in .cbi-title {\
  position: relative;\
  min-height: 2.765rem;\
  display: flex;\
  align-items: center\
}\
.cbi-section.fade-in .cbi-title>div:last-child {\
  position: absolute;\
  right: 1rem\
}\
.cbi-section.fade-in .cbi-title>div:last-child span {\
  display: inline-block;\
  position: relative;\
  font-size: 0\
}\
.cbi-section.fade-in .cbi-title>div:last-child span::after {\
  content: "\\e90f";\
  font-family: '\''argon'\'' !important;\
  font-size: 1.1rem;\
  display: inline-block;\
  transition: transform 0.3s ease;\
  -webkit-font-smoothing: antialiased;\
  line-height: 1\
}\
.cbi-section.fade-in .cbi-title>div:last-child span[data-style='\''inactive'\'']::after {\
  transform: rotate(90deg);\
}
}' feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css

sed -i -e '/btn\.setAttribute(\x27class\x27, include\.hide ? \x27label notice\x27 : \x27label\x27);/d' \
      -e "/\x27class\x27: includes\[i\]\.hide ? \x27label notice\x27 : \x27label\x27,/d" \
         feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js

# Siteyi src/ şablonlarından ve src/i18n/*.json çevirilerinden üretir.
# Kullanım (repo kökünden):  pwsh -NoProfile -File tools/build.ps1
# PowerShell 7 (pwsh) gerekir: yazılar ConvertFrom-Markdown ile çevrilir,
# Windows PowerShell 5.1'de bu komut yok. Windows'ta: winget install Microsoft.PowerShell
#
# Yazılar (haber ve makale): src/writing/<adres>/<dil>.md (dil: en ya da tr). Dosyanın başı:
#   ---
#   title: Başlık
#   type: article                    (article = makale, news = haber; yazılmazsa article)
#   date: 2026-10-30
#   summary: Başlığın altında, listede ve arama sonuçlarında görünen bir-iki cümle
#   author: Ad Soyad                 (isteğe bağlı; yazılmazsa stüdyo adına)
#   image: /writing/<adres>/cover.jpg   (isteğe bağlı kapak; 1024×500 önerilir)
#   canonical: https://medium.com/...   (isteğe bağlı; yazı önce başka yerde yayımlandıysa asıl adresi)
#   ---
# ardından Markdown metin (başlıklar, listeler, alıntı, kod, tablo, dipnot).
# Görseller yayın klasörüne (writing/<adres>/) konur. Görselin hemen altındaki
# *italik* satır görsel açıklaması olarak gösterilir.
# Yazının olmadığı dillerde listede İngilizcesi (yoksa Türkçesi) gösterilir.
#
# Şablon sözdizimi:
#   {{anahtar}}       çeviri metni, olduğu gibi (HTML içerebilir)
#   {{attr:anahtar}}  çeviri metni, HTML özniteliği için kaçışlanmış
#   {{@degisken}}     derleyicinin ürettiği değer (kök yol, dil menüsü, vb.)
# İngilizce sitenin kökünde, diğer diller /<kod>/ altında yayınlanır.
# -AllowMissing: çeviri dosyası henüz olmayan dilleri atlar (sadece yerel deneme için).

# -Only en,tr: sadece bu dilleri üretir (yerel deneme için; sitemap'i yazmaz).

param([switch]$AllowMissing, [string[]]$Only)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'src'
$Site = 'https://thehappysmashiron.com'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Sıra = dil menüsündeki sıra: İngilizce, Türkçe, Avrupa dilleri, en altta Asya dilleri ve Arapça.
# code: klasör adı, tag: lang/hreflang değeri.
$Langs = @(
  @{ code = 'en'; tag = 'en' },
  @{ code = 'tr'; tag = 'tr' },
  @{ code = 'es'; tag = 'es' },
  @{ code = 'fr'; tag = 'fr' },
  @{ code = 'de'; tag = 'de' },
  @{ code = 'it'; tag = 'it' },
  @{ code = 'pt'; tag = 'pt-BR' },
  @{ code = 'nl'; tag = 'nl' },
  @{ code = 'no'; tag = 'nb' },
  @{ code = 'sv'; tag = 'sv' },
  @{ code = 'fi'; tag = 'fi' },
  @{ code = 'cs'; tag = 'cs' },
  @{ code = 'hu'; tag = 'hu' },
  @{ code = 'ru'; tag = 'ru' },
  @{ code = 'zh'; tag = 'zh-Hans' },
  @{ code = 'ja'; tag = 'ja' },
  @{ code = 'hi'; tag = 'hi' },
  @{ code = 'ms'; tag = 'ms' },
  @{ code = 'ar'; tag = 'ar'; rtl = $true }
)

# only: sadece bu dil(ler)de üretilir; fallback: diğer dillerin menüde gideceği sayfa.
# Çeviri dosyası kullanmayan sayfalarda src içindeki {code} dil koduyla değişir;
# titleText/descText dil koduna göre bir tablo da olabilir.
$Pages = @(
  @{ src = 'home.html';      path = '/';                         title = 'home_title';   desc = 'home_desc';   nav = '' },
  @{ src = 'games.html';     path = '/games/';                   title = 'games_title';  desc = 'games_desc';  nav = 'games' },
  @{ src = 'apps.html';      path = '/apps/';                    title = 'apps_title';   desc = 'apps_desc';   nav = 'apps' },
  @{ src = 'studio.html';    path = '/studio/';                  title = 'studio_title'; desc = 'studio_desc'; nav = 'studio' },
  @{ src = 'flicklane.html'; path = '/games/flicklane/';         title = 'fl_title';     desc = 'fl_desc';     nav = 'games' },
  @{ src = 'hourwell.html';  path = '/apps/hourwell/';           title = 'hw_title';     desc = 'hw_desc';     nav = 'apps' },
  @{ src = 'writing.html';   path = '/writing/';                 title = 'writing_title'; desc = 'writing_desc'; nav = 'writing'; tab = '' },
  @{ src = 'writing.html';   path = '/writing/news/';            title = 'writing_title'; desc = 'writing_desc'; nav = 'writing'; tab = 'news' },
  @{ src = 'writing.html';   path = '/writing/articles/';        title = 'writing_title'; desc = 'writing_desc'; nav = 'writing'; tab = 'article' },
  @{ src = 'privacy.html';   path = '/games/flicklane/privacy/'; nav = 'games'; only = 'en'; fallback = '/games/flicklane/';
     titleText = 'Flicklane Privacy Policy · The Happy Smash Iron'; descText = 'How the Flicklane mobile game handles your information.' },
  @{ src = 'hourwell-privacy-{code}.html'; path = '/apps/hourwell/privacy/'; nav = 'apps'; only = @('en', 'tr'); fallback = '/apps/hourwell/';
     titleText = @{ en = 'Hourwell Privacy Policy · The Happy Smash Iron'; tr = 'Hourwell Gizlilik Politikası · The Happy Smash Iron' };
     descText = @{ en = 'How the Hourwell time tracker handles your information.'; tr = 'Hourwell zaman takipçisinin bilgilerinizi nasıl ele aldığı.' } },
  @{ src = '404.html';      path = '/404.html';                 nav = ''; only = 'en'; fallback = '/'; noindex = $true;
     titleText = 'Page not found · The Happy Smash Iron'; descText = 'This page does not exist.' }
)

$TagOf = @{}
foreach ($l in $Langs) { $TagOf[$l.code] = $l.tag }

if ($AllowMissing) {
  $Langs = @($Langs | Where-Object { Test-Path (Join-Path $Src "i18n/$($_.code).json") })
  Write-Host "Diller: $(($Langs | ForEach-Object { $_.code }) -join ', ')"
}

# -File ile çağrılınca "en,tr" tek metin olarak gelir; virgülden ayrılır.
if ($Only) { $Only = @($Only -split ',' | ForEach-Object { $_.Trim() }); $Langs = @($Langs | Where-Object { $Only -contains $_.code }) }

function Read-Text($path) { [System.IO.File]::ReadAllText($path, $Utf8) -replace "`r`n", "`n" }
# Sadece gerekli karakterler kaçışlanır; ·, ’ ve diğer UTF-8 harfler olduğu gibi kalır.
function Enc($s) { ([string]$s).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;') }
function Prefix($code) { if ($code -eq 'en') { '' } else { "/$code" } }

# ---- Çevirileri yükle ve anahtarları İngilizceye göre denetle ----
$Dicts = @{}
foreach ($l in $Langs) {
  $file = Join-Path $Src "i18n/$($l.code).json"
  if (-not (Test-Path $file)) { throw "Eksik çeviri dosyası: $file" }
  $obj = (Read-Text $file) | ConvertFrom-Json
  $h = @{}
  foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = [string]$p.Value }
  $Dicts[$l.code] = $h
}
$enKeys = $Dicts['en'].Keys
$problems = @()
foreach ($l in $Langs) {
  $d = $Dicts[$l.code]
  $missing = $enKeys | Where-Object { -not $d.ContainsKey($_) }
  $extra = $d.Keys | Where-Object { -not $Dicts['en'].ContainsKey($_) }
  if ($missing) { $problems += "$($l.code): eksik anahtar(lar): $($missing -join ', ')" }
  if ($extra) { $problems += "$($l.code): fazla anahtar(lar): $($extra -join ', ')" }
  foreach ($k in $d.Keys) {
    $tagsEn = ([regex]::Matches($Dicts['en'][$k], '<[^>]+>') | ForEach-Object { $_.Value }) -join ''
    $tagsXx = ([regex]::Matches($d[$k], '<[^>]+>') | ForEach-Object { $_.Value }) -join ''
    if ($Dicts['en'].ContainsKey($k) -and $tagsEn -ne $tagsXx) { $problems += "$($l.code).${k}: HTML etiketleri İngilizceyle aynı değil" }
  }
}
if ($problems) { $problems | ForEach-Object { Write-Host $_ -ForegroundColor Red }; throw 'Çeviri denetimi başarısız.' }

$Head = Read-Text (Join-Path $Src 'partials/head.html')
$Footer = Read-Text (Join-Path $Src 'partials/footer.html')
$Rules = Read-Text (Join-Path $Src 'partials/rules.html')
$Globe = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.8 2.6 4 5.6 4 9s-1.2 6.4-4 9c-2.8-2.6-4-5.6-4-9s1.2-6.4 4-9z"/></svg>'

function Render([string]$tpl, [hashtable]$dict, [hashtable]$vars) {
  $eval = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    $name = $m.Groups[3].Value
    if ($m.Groups[2].Value -eq '@') {
      if (-not $vars.ContainsKey($name)) { throw "Bilinmeyen değişken: @$name" }
      return [string]$vars[$name]
    }
    if (-not $dict.ContainsKey($name)) { throw "Bilinmeyen anahtar: $name" }
    if ($m.Groups[1].Success) { return (Enc $dict[$name]) }
    return $dict[$name]
  }
  [regex]::Replace($tpl, '\{\{(attr:)?(@?)([A-Za-z0-9_]+)\}\}', $eval)
}

# ---- Yazıları yükle (en yeni önce) ----
$PostLangs = @('en', 'tr')
$TypeLabels = @{ news = 'writing_type_news'; article = 'writing_type_article' }   # tür -> rozet metni
$TabLabels = @{ news = 'writing_tab_news'; article = 'writing_tab_articles' }     # tür -> sekme metni
$TabPaths = @{ news = 'news'; article = 'articles' }                              # tür -> sekmenin adresi
$Posts = @()
$writingDir = Join-Path $Src 'writing'
if (Test-Path $writingDir) {
  if (-not (Get-Command ConvertFrom-Markdown -ErrorAction SilentlyContinue)) { throw 'Yazılar için PowerShell 7 (pwsh) gerekli.' }
  foreach ($dir in Get-ChildItem $writingDir -Directory) {
    if ($dir.Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "writing/$($dir.Name): adres sadece küçük harf, rakam ve - içerebilir" }
    if ($TabPaths.Values -ccontains $dir.Name) { throw "writing/$($dir.Name): bu adres liste sekmesine ayrılmış, başka bir ad seçin" }
    $versions = @{}
    foreach ($f in Get-ChildItem $dir.FullName -File) {
      $where = "writing/$($dir.Name)/$($f.Name)"
      if ($f.Extension -ne '.md') { continue }
      if ($PostLangs -cnotcontains $f.BaseName) { throw "${where}: dosya adı $($PostLangs -join '.md ya da ').md olmalı" }
      $m = [regex]::Match((Read-Text $f.FullName), '\A---\n(.*?)\n---\n(.*)\z', 'Singleline')
      if (-not $m.Success) { throw "${where}: başta --- satırları arasında title/date/summary bloğu yok" }
      $meta = @{}
      foreach ($line in $m.Groups[1].Value -split "`n") {
        if ($line -match '^\s*([a-z]+)\s*:\s*(.*?)\s*$') { $meta[$Matches[1]] = $Matches[2] -replace '^"(.*)"$', '$1' }
      }
      foreach ($k in 'title', 'date', 'summary') { if (-not $meta[$k]) { throw "${where}: '$k' eksik" } }
      $type = if ($meta.type) { $meta.type } else { 'article' }
      if (-not $TypeLabels.ContainsKey($type)) { throw "${where}: type article ya da news olmalı" }
      if ($meta.canonical -and $meta.canonical -notmatch '^https?://[^\s"<>]+$') { throw "${where}: canonical tam bir adres olmalı (https://...)" }
      $date = [datetime]::MinValue
      if (-not [datetime]::TryParseExact($meta.date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref]$date)) { throw "${where}: tarih YYYY-AA-GG biçiminde olmalı" }
      $body = (ConvertFrom-Markdown -InputObject $m.Groups[2].Value).Html.Trim()
      $words = @(($body -replace '<[^>]+>', ' ') -split '\s+' | Where-Object { $_ }).Count
      $versions[$f.BaseName] = @{
        code = $f.BaseName; title = $meta.title; summary = $meta.summary; type = $type; date = $date
        author = $meta.author; image = $meta.image; canonical = $meta.canonical
        body = $body; minutes = [math]::Max(1, [math]::Round($words / 220))  # dakikada ~220 kelime
      }
    }
    if ($versions.Count) {
      $types = @($versions.Values | ForEach-Object { $_.type } | Select-Object -Unique)
      if ($types.Count -gt 1) { throw "writing/$($dir.Name): type her dilde aynı olmalı" }
      $Posts += @{ slug = $dir.Name; versions = $versions; type = $types[0]; date = ($versions.Values | ForEach-Object { $_.date } | Sort-Object -Descending | Select-Object -First 1) }
    }
  }
  $Posts = @($Posts | Sort-Object @{ e = { $_.date }; Descending = $true }, @{ e = { $_.slug } })
}

# Her yazı, yazıldığı dillerde ayrı sayfa; diğer dillerde menü yazı listesine gider.
foreach ($post in $Posts) {
  $codes = @($PostLangs | Where-Object { $post.versions.ContainsKey($_) })
  $titles = @{}; $descs = @{}
  foreach ($c in $codes) { $titles[$c] = "$($post.versions[$c].title) · The Happy Smash Iron"; $descs[$c] = $post.versions[$c].summary }
  $Pages += @{ src = 'writing-post.html'; path = "/writing/$($post.slug)/"; nav = 'writing'; only = $codes; fallback = '/writing/'; post = $post; titleText = $titles; descText = $descs }
}

$Arrow = '<svg class="arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'

# Tarih ve okuma süresi, sayfanın dilinde (biçimler çeviri dosyasında)
function PostDate($date, $l) { $date.ToString($Dicts[$l.code]['writing_date_format'], [cultureinfo]::GetCultureInfo($l.tag)) }
function ReadTime($v, $l) { $Dicts[$l.code]['writing_min_read'].Replace('{n}', [string]$v.minutes) }

# Yazı kartları ($type: sadece bu tür); sayfanın dilinde yazı yoksa İngilizcesi, o da yoksa Türkçesi (dil etiketiyle)
function PostCards($l, [int]$max, [string]$hx, [string]$type) {
  $d = $Dicts[$l.code]
  $list = @($Posts | Where-Object { -not $type -or $_.type -eq $type } | Select-Object -First $(if ($max) { $max } else { [int]::MaxValue }))
  if (-not $list) { return "        <div class=`"placeholder`">`n          <p>$($d['writing_empty'])</p>`n        </div>" }
  $cards = foreach ($post in $list) {
    $v = foreach ($c in @($l.code, 'en', 'tr')) { if ($post.versions.ContainsKey($c)) { $post.versions[$c]; break } }
    $vtag = $TagOf[$v.code]
    $lang = if ($v.code -ne $l.code) { " lang=`"$vtag`"" + $(if ($l.rtl) { ' dir="ltr"' }) } else { '' }
    $badge = if ($v.code -ne $l.code) { " <span class=`"en-tag`" lang=`"$vtag`">$($v.code.ToUpperInvariant())</span>" } else { '' }
    $lines = @("          <a class=`"post-card`" href=`"$(Prefix $v.code)/writing/$($post.slug)/`" hreflang=`"$vtag`">")
    if ($v.image) { $lines += "            <div class=`"thumb`"><img src=`"$(Enc $v.image)`" alt=`"`" width=`"1024`" height=`"500`" loading=`"lazy`"></div>" }
    $lines += @(
      '            <div class="body">',
      "              <p class=`"meta`"><span class=`"kind`">$($d[$TypeLabels[$post.type]])</span> <time datetime=`"$($v.date.ToString('yyyy-MM-dd'))`">$(PostDate $v.date $l)</time> · <span class=`"read`">$(ReadTime $v $l)</span>$badge</p>",
      "              <$hx$lang>$(Enc $v.title)</$hx>",
      "              <p$lang>$(Enc $v.summary)</p>",
      "              <span class=`"go`">$($d['writing_read'])`n                $Arrow</span>",
      '            </div>',
      '          </a>'
    )
    $lines -join "`n"
  }
  "        <div class=`"post-list`">`n$($cards -join "`n")`n        </div>"
}

$sitemap = New-Object System.Collections.Generic.List[string]
$count = 0
# Tablo verilmişse bu dilin değeri, değilse değerin kendisi
function PerLang($v, $code) { if ($v -is [hashtable]) { $v[$code] } else { $v } }

# Hourwell gizlilik politikası İngilizce ve Türkçe; diğer diller İngilizcesine gider.
$HwPrivacyLangs = ($Pages | Where-Object { $_.path -eq '/apps/hourwell/privacy/' }).only

foreach ($page in $Pages) {
  $pageLangs = @(if ($page.only) { $Langs | Where-Object { $page.only -contains $_.code } } else { $Langs })

  # Bu sayfanın dil karşılıkları (hreflang); tek dilli sayfalarda yok
  $alt = @()
  if ($page.noindex) {
    $alt += '  <meta name="robots" content="noindex">'
  } elseif ($pageLangs.Count -gt 1) {
    foreach ($l in $pageLangs) { $alt += "  <link rel=`"alternate`" hreflang=`"$($l.tag)`" href=`"$Site$(Prefix $l.code)$($page.path)`">" }
    $alt += "  <link rel=`"alternate`" hreflang=`"x-default`" href=`"$Site$($page.path)`">"
  }

  foreach ($l in $pageLangs) {
    $d = $Dicts[$l.code]
    $prefix = Prefix $l.code
    $body = (Read-Text (Join-Path $Src "pages/$($page.src.Replace('{code}', $l.code))")).Replace('{{@rules}}', $Rules.TrimEnd("`n"))
    $tpl = $Head + "`n" + $body.TrimEnd("`n") + "`n`n" + $Footer
    $hwp = if ($HwPrivacyLangs -contains $l.code) { $l } else { @{ code = 'en'; tag = 'en' } }

    $items = foreach ($o in $Langs) {
      $target = if ($page.only -and $page.only -notcontains $o.code) { $page.fallback } else { $page.path }
      $cur = if ($o.code -eq $l.code) { ' aria-current="true"' } else { '' }
      "            <li><a href=`"$(Prefix $o.code)$target`" hreflang=`"$($o.tag)`" lang=`"$($o.tag)`"$cur>$(Enc $Dicts[$o.code]['lang_name'])</a></li>"
    }
    $menu = @(
      '        <details class="lang-menu">',
      "          <summary aria-label=`"$(Enc $d['lang_label']): $(Enc $d['lang_name'])`">$Globe<span>$($l.code.ToUpperInvariant())</span></summary>",
      '          <ul>'
    ) + $items + @('          </ul>', '        </details>')

    $vars = @{
      hreflang   = $l.tag
      dir        = $(if ($l.rtl) { 'rtl' } else { 'ltr' })
      title      = Enc $(if ($page.titleText) { PerLang $page.titleText $l.code } else { $d[$page.title] })
      desc       = Enc $(if ($page.descText) { PerLang $page.descText $l.code } else { $d[$page.desc] })
      root       = $prefix
      shots      = $(if ($l.code -eq 'tr') { 'tr' } else { 'en' })  # Hourwell ekran görüntüleri: Türkçe ya da İngilizce
      sp         =$(if ($l.code -in @('zh', 'ja')) { '' } else { ' ' })  # Çince/Japoncada kelime arası boşluk yok
      alternates = $alt -join "`n"
      langmenu   = $menu -join "`n"
      cur_games  = $(if ($page.nav -eq 'games') { ' aria-current="page"' } else { '' })
      cur_apps   = $(if ($page.nav -eq 'apps') { ' aria-current="page"' } else { '' })
      cur_studio = $(if ($page.nav -eq 'studio') { ' aria-current="page"' } else { '' })
      cur_writing = $(if ($page.nav -eq 'writing') { ' aria-current="page"' } else { '' })
      canonical  = "$Site$prefix$($page.path)"
      og_image   = "$Site/assets/brand/icon-512.png"
      en_only    = $(if ($l.code -eq 'en') { '' } else { ' <span class="en-tag" lang="en">EN</span>' })
      hw_privacy = "href=`"$(Prefix $hwp.code)/apps/hourwell/privacy/`" hreflang=`"$($hwp.tag)`""
      hw_privacy_tag = $(if ($hwp.code -eq $l.code) { '' } else { ' <span class="en-tag" lang="en">EN</span>' })
    }
    $external = $false  # yazının asıl adresi başka sitede mi (sitemap'e girmez)
    if ($page.src -eq 'home.html') { $vars.latest_writing = PostCards $l 3 'h3' '' }
    if ($page.src -eq 'writing.html') {
      $vars.writing_list = PostCards $l 0 'h2' $page.tab
      foreach ($t in '', 'news', 'article') { $vars["tab_$(if ($t) { $TabPaths[$t] } else { 'all' })"] = $(if ($page.tab -eq $t) { ' aria-current="page"' } else { '' }) }
      if ($page.tab) { $vars.title = Enc "$($d[$TabLabels[$page.tab]]) · $($d[$page.title])" }
    }
    if ($page.post) {
      $v = $page.post.versions[$l.code]
      $vars.post_title = Enc $v.title
      $vars.post_summary = Enc $v.summary
      $vars.post_kind = $d[$TypeLabels[$v.type]]
      $vars.post_tab = $d[$TabLabels[$v.type]]
      $vars.post_tab_path = $TabPaths[$v.type]
      $vars.post_byline = $(if ($v.author) { "<span class=`"author`">$(Enc $v.author)</span> · " } else { '' })
      $vars.post_iso = $v.date.ToString('yyyy-MM-dd')
      $vars.post_date = PostDate $v.date $l
      $vars.post_read = ReadTime $v $l
      $vars.post_body = $v.body
      $vars.post_cover = $(if ($v.image) { "    <img class=`"post-cover`" src=`"$(Enc $v.image)`" alt=`"`" width=`"1024`" height=`"500`">" } else { '' })
      $vars.post_original = ''
      if ($v.image -like '/*') { $vars.og_image = Enc "$Site$($v.image)" }
      if ($v.canonical) {
        $external = $true
        $vars.canonical = Enc $v.canonical
        $link = "<a href=`"$(Enc $v.canonical)`">$(Enc (([uri]$v.canonical).Host -replace '^www\.', ''))</a>"
        $vars.post_original = "    <p class=`"post-original`">$($d['writing_original'].Replace('{link}', $link))</p>"
      }
    }

    $html = Render $tpl $d $vars
    $rel = if ($page.path.EndsWith('/')) { "$prefix$($page.path)index.html" } else { $page.path }
    $out = Join-Path $Root $rel.TrimStart('/')
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    [System.IO.File]::WriteAllText($out, $html, $Utf8)
    $count++

    $indexed = -not $page.noindex -and -not $external
    if ($indexed -and $pageLangs.Count -gt 1) {
      $links = ($pageLangs | ForEach-Object { "    <xhtml:link rel=`"alternate`" hreflang=`"$($_.tag)`" href=`"$Site$(Prefix $_.code)$($page.path)`"/>" }) -join "`n"
      $sitemap.Add("  <url>`n    <loc>$Site$prefix$($page.path)</loc>`n$links`n  </url>")
    } elseif ($indexed) {
      $sitemap.Add("  <url>`n    <loc>$Site$prefix$($page.path)</loc>`n  </url>")
    }
  }
}

# Silinen ya da o dilden kaldırılan yazıların eski sayfaları; klasördeki görseller kalır.
foreach ($l in $Langs) {
  $dir = Join-Path $Root "$(Prefix $l.code)/writing".TrimStart('/')
  if (-not (Test-Path $dir)) { continue }
  foreach ($sub in Get-ChildItem $dir -Directory) {
    if ($TabPaths.Values -ccontains $sub.Name) { continue }
    $post = $Posts | Where-Object { $_.slug -ceq $sub.Name }
    $page = Join-Path $sub.FullName 'index.html'
    if ((-not $post -or -not $post.versions.ContainsKey($l.code)) -and (Test-Path $page)) {
      Remove-Item $page
      if (-not (Get-ChildItem $sub.FullName -Force)) { Remove-Item $sub.FullName }
      Write-Host "Kaldırıldı: $(Prefix $l.code)/writing/$($sub.Name)/"
    }
  }
}

$xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`" xmlns:xhtml=`"http://www.w3.org/1999/xhtml`">`n" + ($sitemap -join "`n") + "`n</urlset>`n"
if (-not $Only -and -not $AllowMissing) { [System.IO.File]::WriteAllText((Join-Path $Root 'sitemap.xml'), $xml, $Utf8) }
Write-Host "Tamam: $count sayfa, $($Langs.Count) dil, sitemap.xml ($($sitemap.Count) adres)."

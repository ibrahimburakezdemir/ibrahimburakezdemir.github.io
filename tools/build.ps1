# Siteyi src/ şablonlarından ve src/i18n/*.json çevirilerinden üretir.
# Kullanım (repo kökünden):  powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1
#
# Şablon sözdizimi:
#   {{anahtar}}       çeviri metni, olduğu gibi (HTML içerebilir)
#   {{attr:anahtar}}  çeviri metni, HTML özniteliği için kaçışlanmış
#   {{@degisken}}     derleyicinin ürettiği değer (kök yol, dil menüsü, vb.)
# İngilizce sitenin kökünde, diğer diller /<kod>/ altında yayınlanır.
# -AllowMissing: çeviri dosyası henüz olmayan dilleri atlar (sadece yerel deneme için).

param([switch]$AllowMissing)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'src'
$Site = 'https://thehappysmashiron.com'
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Sıra = dil menüsündeki sıra. code: klasör adı, tag: lang/hreflang değeri.
$Langs = @(
  @{ code = 'tr'; tag = 'tr' },
  @{ code = 'en'; tag = 'en' },
  @{ code = 'es'; tag = 'es' },
  @{ code = 'fr'; tag = 'fr' },
  @{ code = 'de'; tag = 'de' },
  @{ code = 'it'; tag = 'it' },
  @{ code = 'pt'; tag = 'pt-BR' },
  @{ code = 'ar'; tag = 'ar'; rtl = $true },
  @{ code = 'hi'; tag = 'hi' },
  @{ code = 'zh'; tag = 'zh-Hans' },
  @{ code = 'ru'; tag = 'ru' },
  @{ code = 'ms'; tag = 'ms' },
  @{ code = 'nl'; tag = 'nl' },
  @{ code = 'no'; tag = 'nb' },
  @{ code = 'sv'; tag = 'sv' },
  @{ code = 'fi'; tag = 'fi' },
  @{ code = 'hu'; tag = 'hu' },
  @{ code = 'cs'; tag = 'cs' },
  @{ code = 'ja'; tag = 'ja' }
)

# only: sadece bu dilde üretilir; fallback: diğer dillerin menüde gideceği sayfa.
$Pages = @(
  @{ src = 'home.html';      path = '/';                         title = 'home_title';   desc = 'home_desc';   nav = '' },
  @{ src = 'games.html';     path = '/games/';                   title = 'games_title';  desc = 'games_desc';  nav = 'games' },
  @{ src = 'apps.html';      path = '/apps/';                    title = 'apps_title';   desc = 'apps_desc';   nav = 'apps' },
  @{ src = 'studio.html';    path = '/studio/';                  title = 'studio_title'; desc = 'studio_desc'; nav = 'studio' },
  @{ src = 'flicklane.html'; path = '/games/flicklane/';         title = 'fl_title';     desc = 'fl_desc';     nav = 'games' },
  @{ src = 'privacy.html';   path = '/games/flicklane/privacy/'; nav = 'games'; only = 'en'; fallback = '/games/flicklane/';
     titleText = 'Flicklane Privacy Policy · The Happy Smash Iron'; descText = 'How the Flicklane mobile game handles your information.' },
  @{ src = '404.html';       path = '/404.html';                 nav = ''; only = 'en'; fallback = '/'; noindex = $true;
     titleText = 'Page not found · The Happy Smash Iron'; descText = 'This page does not exist.' }
)

if ($AllowMissing) {
  $Langs = @($Langs | Where-Object { Test-Path (Join-Path $Src "i18n\$($_.code).json") })
  Write-Host "Diller: $(($Langs | ForEach-Object { $_.code }) -join ', ')"
}

function Read-Text($path) { [System.IO.File]::ReadAllText($path, $Utf8) -replace "`r`n", "`n" }
# Sadece gerekli karakterler kaçışlanır; ·, ’ ve diğer UTF-8 harfler olduğu gibi kalır.
function Enc($s) { ([string]$s).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;') }
function Prefix($code) { if ($code -eq 'en') { '' } else { "/$code" } }

# ---- Çevirileri yükle ve anahtarları İngilizceye göre denetle ----
$Dicts = @{}
foreach ($l in $Langs) {
  $file = Join-Path $Src "i18n\$($l.code).json"
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

$Head = Read-Text (Join-Path $Src 'partials\head.html')
$Footer = Read-Text (Join-Path $Src 'partials\footer.html')
$Rules = Read-Text (Join-Path $Src 'partials\rules.html')
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

$sitemap = New-Object System.Collections.Generic.List[string]
$count = 0
foreach ($page in $Pages) {
  $body = (Read-Text (Join-Path $Src "pages\$($page.src)")).Replace('{{@rules}}', $Rules.TrimEnd("`n"))
  $tpl = $Head + "`n" + $body.TrimEnd("`n") + "`n`n" + $Footer
  $pageLangs = if ($page.only) { $Langs | Where-Object { $_.code -eq $page.only } } else { $Langs }

  # Bu sayfanın dil karşılıkları (hreflang)
  $alt = @()
  if ($page.noindex) {
    $alt += '  <meta name="robots" content="noindex">'
  } elseif (-not $page.only) {
    foreach ($l in $Langs) { $alt += "  <link rel=`"alternate`" hreflang=`"$($l.tag)`" href=`"$Site$(Prefix $l.code)$($page.path)`">" }
    $alt += "  <link rel=`"alternate`" hreflang=`"x-default`" href=`"$Site$($page.path)`">"
  }

  foreach ($l in $pageLangs) {
    $d = $Dicts[$l.code]
    $prefix = Prefix $l.code

    $items = foreach ($o in $Langs) {
      $target = if ($page.only -and $o.code -ne $page.only) { $page.fallback } else { $page.path }
      $cur = if ($o.code -eq $l.code) { ' aria-current="true"' } else { '' }
      "            <li><a href=`"$(Prefix $o.code)$target`" hreflang=`"$($o.tag)`" lang=`"$($o.tag)`"$cur>$(Enc $Dicts[$o.code]['lang_name'])</a></li>"
    }
    $menu = @(
      '        <details class="lang-menu">',
      "          <summary aria-label=`"$(Enc $d['lang_label']): $(Enc $d['lang_name'])`">$Globe<span>$($l.code.ToUpper())</span></summary>",
      '          <ul>'
    ) + $items + @('          </ul>', '        </details>')

    $vars = @{
      hreflang   = $l.tag
      dir        = $(if ($l.rtl) { 'rtl' } else { 'ltr' })
      title      = Enc $(if ($page.titleText) { $page.titleText } else { $d[$page.title] })
      desc       = Enc $(if ($page.descText) { $page.descText } else { $d[$page.desc] })
      url        = $prefix + $page.path
      root       = $prefix
      sp         = $(if ($l.code -in @('zh', 'ja')) { '' } else { ' ' })  # Çince/Japoncada kelime arası boşluk yok
      alternates = $alt -join "`n"
      langmenu   = $menu -join "`n"
      cur_games  = $(if ($page.nav -eq 'games') { ' aria-current="page"' } else { '' })
      cur_apps   = $(if ($page.nav -eq 'apps') { ' aria-current="page"' } else { '' })
      cur_studio = $(if ($page.nav -eq 'studio') { ' aria-current="page"' } else { '' })
      en_only    = $(if ($l.code -eq 'en') { '' } else { ' <span class="en-tag" lang="en">EN</span>' })
    }

    $html = Render $tpl $d $vars
    $rel = if ($page.path.EndsWith('/')) { "$prefix$($page.path)index.html" } else { $page.path }
    $out = Join-Path $Root ($rel.TrimStart('/') -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    [System.IO.File]::WriteAllText($out, $html, $Utf8)
    $count++

    if (-not $page.noindex -and -not $page.only) {
      $links = ($Langs | ForEach-Object { "    <xhtml:link rel=`"alternate`" hreflang=`"$($_.tag)`" href=`"$Site$(Prefix $_.code)$($page.path)`"/>" }) -join "`n"
      $sitemap.Add("  <url>`n    <loc>$Site$prefix$($page.path)</loc>`n$links`n  </url>")
    } elseif (-not $page.noindex) {
      $sitemap.Add("  <url>`n    <loc>$Site$prefix$($page.path)</loc>`n  </url>")
    }
  }
}

$xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`" xmlns:xhtml=`"http://www.w3.org/1999/xhtml`">`n" + ($sitemap -join "`n") + "`n</urlset>`n"
[System.IO.File]::WriteAllText((Join-Path $Root 'sitemap.xml'), $xml, $Utf8)
Write-Host "Tamam: $count sayfa, $($Langs.Count) dil, sitemap.xml ($($sitemap.Count) adres)."

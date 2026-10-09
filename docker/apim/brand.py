#!/usr/bin/env python3
"""Applies Jamii Savings branding to an unpacked WSO2 API Manager 4.4 at build time.

Usage: brand.py <APIM_HOME> <branding-dir>
Prints every change so the build log shows exactly what was branded and what was not found.
"""
import base64, glob, os, re, shutil, subprocess, sys, tempfile

APIM, BRAND = sys.argv[1], sys.argv[2]
WEBAPPS = os.path.join(APIM, 'repository/deployment/server/webapps')
IMG = os.path.join(BRAND, 'images')

def log(msg): print(f'brand: {msg}', flush=True)

def b64(name):
    with open(os.path.join(IMG, name), 'rb') as f: return base64.b64encode(f.read()).decode()

def svg_wrapper(original_svg, png_name):
    """New SVG with the original's size and viewBox, showing our PNG scaled to fit (no distortion)."""
    txt = open(original_svg, encoding='utf-8', errors='ignore').read()
    root = re.search(r'<svg\b[^>]*>', txt, re.S)
    attrs = root.group(0) if root else ''
    def attr(n):
        m = re.search(rf'\b{n}\s*=\s*"([^"]+)"', attrs); return m.group(1) if m else None
    vb = attr('viewBox')
    w, h = attr('width'), attr('height')
    if not vb:
        try: vb = f'0 0 {float(re.sub("[a-z%]", "", w))} {float(re.sub("[a-z%]", "", h))}'
        except Exception: vb = '0 0 300 120'
    x, y, vw, vh = vb.replace(',', ' ').split()[:4]
    size = ''.join(f' {k}="{v}"' for k, v in (('width', w), ('height', h)) if v)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="{vb}"{size}>'
            f'<image x="{x}" y="{y}" width="{vw}" height="{vh}" preserveAspectRatio="xMidYMid meet" '
            f'href="data:image/png;base64,{b64(png_name)}" xlink:href="data:image/png;base64,{b64(png_name)}"/></svg>')

def replace_logos(root, variant_png, skip=('/custom/', '/jamii/')):
    found = 0
    for path in glob.glob(os.path.join(root, '**', '*'), recursive=True):
        base = os.path.basename(path).lower()
        if not os.path.isfile(path) or 'logo' not in base or any(s in path for s in skip):
            continue
        if base.endswith('.svg'):
            new_svg = svg_wrapper(path, variant_png)   # read the original before truncating it
            open(path, 'w').write(new_svg); found += 1
        elif base.endswith('.png'):
            shutil.copy(os.path.join(IMG, variant_png), path); found += 1
        else:
            continue
        log(f'  logo replaced: {os.path.relpath(path, WEBAPPS)}')
    if not found: log(f'  WARN no logo files found under {os.path.relpath(root, WEBAPPS)}')

def replace_favicons(root):
    for path in glob.glob(os.path.join(root, '**', 'favicon*'), recursive=True):
        if '/custom/' in path or '/jamii/' in path: continue
        ext = os.path.splitext(path)[1].lower()
        if ext in ('.png', '.ico'):
            shutil.copy(os.path.join(IMG, 'favicon' + ext), path); log(f'  favicon replaced: {os.path.relpath(path, WEBAPPS)}')

def copy_images(app_public):
    dst = os.path.join(app_public, 'images', 'custom'); os.makedirs(dst, exist_ok=True)
    for f in os.listdir(IMG): shutil.copy(os.path.join(IMG, f), dst)

# ---------------- Developer Portal ----------------
dp = os.path.join(WEBAPPS, 'devportal', 'site', 'public')
if os.path.isdir(dp):
    log('devportal:')
    copy_images(dp)
    target = os.path.join(dp, 'theme', 'userTheme.json')
    if os.path.exists(target): shutil.copy(target, target + '.wso2-default')
    shutil.copy(os.path.join(BRAND, 'devportal', 'userTheme.json'), target)
    log('  theme written: devportal/site/public/theme/userTheme.json (served as /devportal/site/public/theme/userTheme.js)')
    replace_logos(os.path.join(dp, 'images'), 'jamii-logo-header.png')
    replace_favicons(dp)
    # Empty-state artwork ("No APIs Available"): replace with the Jamii symbol where it is an image file
    hits = 0
    for path in glob.glob(os.path.join(dp, 'images', '**', '*'), recursive=True):
        name = os.path.basename(path).lower()
        if '/custom/' in path or not os.path.isfile(path): continue
        if re.search(r'(no[-_]?api|noapis|empty|no[-_]?data|nodata|no[-_]?content|maintenance)', name):
            if name.endswith('.svg'):
                new_svg = svg_wrapper(path, 'jamii-mark.png'); open(path, 'w').write(new_svg)
            elif name.endswith('.png'):
                shutil.copy(os.path.join(IMG, 'jamii-mark.png'), path)
            else: continue
            hits += 1; log(f'  empty-state image replaced: {os.path.relpath(path, WEBAPPS)}')
    if not hits: log('  INFO no empty-state image file found (it is drawn inline in this release; left as default)')
else:
    log('WARN devportal webapp not found')

# ---------------- Publisher ----------------
pub = os.path.join(WEBAPPS, 'publisher', 'site', 'public')
if os.path.isdir(pub):
    log('publisher:')
    copy_images(pub)
    target = os.path.join(pub, 'conf', 'userThemes.js')
    if os.path.exists(target): shutil.copy(target, target + '.wso2-default')
    shutil.copy(os.path.join(BRAND, 'publisher', 'userThemes.js'), target)
    log('  theme written: publisher/site/public/conf/userThemes.js')
    stray = os.path.join(pub, 'conf', 'userCustomThemes.js')
    if os.path.exists(stray): os.remove(stray)
    replace_logos(os.path.join(pub, 'images'), 'jamii-logo-header-white.png')
    replace_favicons(pub)

# ---------------- Admin Portal (no theme file in 4.4: logos and favicon only) ----------------
adm = os.path.join(WEBAPPS, 'admin', 'site', 'public')
if os.path.isdir(adm):
    log('admin:')
    copy_images(adm)
    stray = os.path.join(adm, 'conf', 'userCustomThemes.js')
    if os.path.exists(stray): os.remove(stray)
    replace_logos(os.path.join(adm, 'images'), 'jamii-logo-header-white.png')
    replace_favicons(adm)

# ---------------- Sign-in page (authenticationendpoint) ----------------
def brand_login(root):
    login = os.path.join(BRAND, 'login')
    os.makedirs(os.path.join(root, 'extensions'), exist_ok=True)
    os.makedirs(os.path.join(root, 'css'), exist_ok=True)
    os.makedirs(os.path.join(root, 'images', 'jamii'), exist_ok=True)
    shutil.copy(os.path.join(login, 'jamii-login.css'), os.path.join(root, 'css', 'jamii-login.css'))
    for f in ('jamii-logo-full.png', 'favicon.png', 'favicon.ico'):
        shutil.copy(os.path.join(IMG, f), os.path.join(root, 'images', 'jamii', f))
    for f in ('product-title.jsp', 'product-footer.jsp'):
        shutil.copy(os.path.join(login, f), os.path.join(root, 'extensions', f)); log(f'  extension written: extensions/{f}')
    default_header = os.path.join(root, 'includes', 'header.jsp')
    if os.path.exists(default_header):
        header = open(default_header, encoding='utf-8').read()
        header = re.sub(r'<title>.*?</title>', '<title>Jamii Savings | Sign in</title>', header, flags=re.S)
        header += ('\n<%-- Jamii Savings branding --%>\n'
                   '<link rel="stylesheet" href="css/jamii-login.css">\n'
                   '<link rel="icon" href="images/jamii/favicon.png" type="image/png">\n')
        open(os.path.join(root, 'extensions', 'header.jsp'), 'w', encoding='utf-8').write(header)
        log('  extension written: extensions/header.jsp (default header + Jamii stylesheet, title, favicon)')
    else:
        log('  WARN includes/header.jsp not found; header files present:')
        for p in glob.glob(os.path.join(root, '**', '*header*.jsp'), recursive=True): log(f'    {os.path.relpath(p, root)}')
    uses_ext = [os.path.relpath(p, root) for p in glob.glob(os.path.join(root, '*.jsp'))
                if 'extensions/header.jsp' in open(p, encoding='utf-8', errors='ignore').read()]
    log(f'  pages that load extensions/header.jsp: {", ".join(sorted(uses_ext)[:6]) or "NONE (send me the build log)"}')
    replace_logos(root, 'jamii-logo-full.png')
    replace_favicons(root)

auth_dir = os.path.join(WEBAPPS, 'authenticationendpoint')
auth_war = auth_dir + '.war'
if os.path.isdir(auth_dir):
    log('sign-in page (authenticationendpoint, folder):'); brand_login(auth_dir)
elif os.path.isfile(auth_war):
    log('sign-in page (authenticationendpoint.war):')
    tmp = tempfile.mkdtemp()
    subprocess.run(['unzip', '-q', auth_war, '-d', tmp], check=True)
    brand_login(tmp)
    os.remove(auth_war)
    subprocess.run(['zip', '-qr', auth_war, '.'], cwd=tmp, check=True)
    log('  war repacked')
else:
    log('WARN authenticationendpoint not found under webapps')
log('done')

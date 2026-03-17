#!/bin/bash
set -e

# テーマ名設定（.env で必須指定）
if [ -z "${THEME_NAME:-}" ]; then
  echo "[wp-init] ERROR: THEME_NAME is not set. Please define THEME_NAME in .env." >&2
  exit 1
fi

echo "=========================================="
echo "WordPress Initialization Script"
echo "Theme: $THEME_NAME"
echo "=========================================="

# WordPress インストール
echo "[1/15] Installing WordPress..."
wp core install \
    --url="${WP_HOME}" \
    --title="${WP_SITE_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email --allow-root --path=/var/www/html 2>/dev/null || echo "WordPress already installed"

echo "✓ WordPress installed!"

# WordPress日本語化
echo "[2/15] Installing Japanese language..."
wp core language install ja --allow-root --path=/var/www/html 2>/dev/null || true
wp site switch-language ja --allow-root --path=/var/www/html 2>/dev/null || true

# 一般設定
echo "[3/15] Configuring general settings..."
wp option update timezone_string 'Asia/Tokyo' --allow-root --path=/var/www/html
wp option update date_format 'Y.m.d' --allow-root --path=/var/www/html
wp option update time_format 'H:i' --allow-root --path=/var/www/html

# パーマリンク設定
echo "[4/15] Setting permalinks..."
wp rewrite structure '/%postname%/' --allow-root --path=/var/www/html 2>/dev/null || true
wp rewrite flush --allow-root --path=/var/www/html

# デフォルトコンテンツの削除
echo "[5/15] Deleting default content..."

# デフォルト投稿削除（Hello worldなど）
wp post delete $(wp post list --post_type=post --format=ids --allow-root --path=/var/www/html) --force --allow-root --path=/var/www/html 2>/dev/null || true

# デフォルト固定ページ削除（Sample Pageなど）
wp post delete $(wp post list --post_type=page --format=ids --allow-root --path=/var/www/html) --force --allow-root --path=/var/www/html 2>/dev/null || true

# デフォルトプラグイン削除（Akismet, Hello Dolly）
wp plugin delete akismet hello --allow-root --path=/var/www/html 2>/dev/null || true

echo "✓ Default content deleted!"

# テーマ有効化
echo "[6/15] Activating theme..."
wp theme activate $THEME_NAME --allow-root --path=/var/www/html 2>/dev/null || echo "Theme $THEME_NAME not found"

# プラグイン有効化
echo "[7/15] Activating plugins..."
PLUGINS=(
    "advanced-custom-fields"
    "tinymce-advanced"
    "classic-editor"
    "contact-form-7"
    "contact-form-cfdb7"
    "wp-multibyte-patch"
)

for plugin in "${PLUGINS[@]}"; do
    wp plugin activate "$plugin" --allow-root --path=/var/www/html 2>/dev/null || echo "Plugin $plugin not found"
done

echo "✓ Plugins activated!"

# Contact Form 7のフォームテンプレート更新
echo "[7.5/15] Updating Contact Form 7 template..."

CF7_TITLE=${CF7_TITLE}
FORM_HTML_FILE="/var/www/html/wp-content/themes/$THEME_NAME/template-parts/cf7-form.html"

if [ ! -f "$FORM_HTML_FILE" ]; then
  echo "⚠ Form HTML file not found: $FORM_HTML_FILE"
  exit 0
fi

# タイトル一致のフォームIDを探す（検索→完全一致で確定）
FORM_ID=""
CANDIDATE_IDS=$(wp post list \
  --post_type=wpcf7_contact_form \
  --search="$CF7_TITLE" \
  --field=ID \
  --allow-root --path=/var/www/html 2>/dev/null)

if [ -n "$CANDIDATE_IDS" ]; then
  for id in $CANDIDATE_IDS; do
    t=$(wp post get "$id" --field=post_title --allow-root --path=/var/www/html 2>/dev/null)
    if [ "$t" = "$CF7_TITLE" ]; then
      FORM_ID="$id"
      break
    fi
  done
fi

if [ -z "$FORM_ID" ]; then
  echo "⚠ Contact Form '$CF7_TITLE' not found"
  exit 0
fi

wp post meta update "$FORM_ID" _form "$(<"$FORM_HTML_FILE")" --allow-root --path=/var/www/html
echo "✓ Contact Form template updated (Title: $CF7_TITLE, ID: $FORM_ID)"


# 固定ページ作成（公開状態）
echo "[8/15] Creating pages..."
wp post create --post_type=page \
    --post_title='All' \
    --post_name='blog' \
    --post_status=publish --allow-root --path=/var/www/html 2>/dev/null || true

PAGE_ID=$(wp post create --post_type=page \
    --post_title='Contact' \
    --post_name='contact' \
    --post_status=publish --porcelain --allow-root --path=/var/www/html)
wp post meta update $PAGE_ID text1 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_1</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text2 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_2</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text3 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_3</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text4 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_4</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text5 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_5</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text6 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_6</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text7 "$(cat <<'EOF'
<p>YOUR_PRIVACY_POLICY_TEXT_7</p>
EOF
)" --allow-root --path=/var/www/html

PAGE_ID=$(wp post create --post_type=page \
    --post_title='Gallery' \
    --post_name='gallery' \
    --post_status=publish --porcelain --allow-root --path=/var/www/html)
OEMBED1="https://YOUR_OEMBED_URL/1"
OEMBED2="https://YOUR_OEMBED_URL/2"
OEMBED3="https://YOUR_OEMBED_URL/3"
OEMBED4="https://YOUR_OEMBED_URL/4"
OEMBED5="https://YOUR_OEMBED_URL/5"

wp eval "update_field('field_gallery_oembed1', '$OEMBED1', $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_gallery_oembed2', '$OEMBED2', $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_gallery_oembed3', '$OEMBED3', $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_gallery_oembed4', '$OEMBED4', $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_gallery_oembed5', '$OEMBED5', $PAGE_ID);" --allow-root --path=/var/www/html

PAGE_ID=$(wp post create --post_type=page \
    --post_title='Home' \
    --post_name='home' \
    --post_status=publish --porcelain --allow-root --path=/var/www/html)
wp post meta update $PAGE_ID text1 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_TITLE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text2 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_DESCRIPTION</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text3 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_PRICE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text4 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_TITLE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text5 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_DESCRIPTION</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text6 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_PRICE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text7 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_TITLE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text8 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_DESCRIPTION</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text9 "$(cat <<'EOF'
<p>YOUR_MEMBERSHIP_PRICE</p>
EOF
)" --allow-root --path=/var/www/html

wp post meta update $PAGE_ID link1 "https://YOUR_EXTERNAL_URL/1" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID link2 "https://YOUR_EXTERNAL_URL/2" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID link3 "https://YOUR_EXTERNAL_URL/3" --allow-root --path=/var/www/html

IMG1=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide1.jpg --porcelain --allow-root --path=/var/www/html)
IMG2=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide2.jpg --porcelain --allow-root --path=/var/www/html)
IMG3=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide3.jpg --porcelain --allow-root --path=/var/www/html)
IMG4=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide4.jpg --porcelain --allow-root --path=/var/www/html)
IMG5=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide-m1.png --porcelain --allow-root --path=/var/www/html)
IMG6=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide-m2.png --porcelain --allow-root --path=/var/www/html)
IMG7=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide-m3.png --porcelain --allow-root --path=/var/www/html)
IMG8=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/slide-m4.png --porcelain --allow-root --path=/var/www/html)
IMG9=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/membership1.png --porcelain --allow-root --path=/var/www/html)
IMG10=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/membership2.png --porcelain --allow-root --path=/var/www/html)
IMG11=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/membership3.png --porcelain --allow-root --path=/var/www/html)

wp eval "update_field('field_home_img1', $IMG1, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img2', $IMG2, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img3', $IMG3, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img4', $IMG4, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img5', $IMG5, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img6', $IMG6, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img7', $IMG7, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img8', $IMG8, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img9', $IMG9, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img10', $IMG10, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_img11', $IMG11, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_home_oembed1', 'https://YOUR_OEMBED_URL/6', $PAGE_ID);" --allow-root --path=/var/www/html

PAGE_ID=$(wp post create --post_type=page \
    --post_title='Lesson' \
    --post_name='lesson' \
    --post_status=publish --porcelain --allow-root --path=/var/www/html)
wp post meta update $PAGE_ID text1 "$(cat <<'EOF'
<p>YOUR_LESSON_DESCRIPTION</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text2 "$(cat <<'EOF'
<p>YOUR_LESSON_PRICE_1</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text3 "$(cat <<'EOF'
<p>YOUR_LESSON_PRICE_2</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text4 "$(cat <<'EOF'
<p>YOUR_LESSON_NOTE</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text5 "$(cat <<'EOF'
<p>YOUR_REVIEWER_1</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text6 "$(cat <<'EOF'
<p>YOUR_REVIEW_TITLE_1</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text7 "$(cat <<'EOF'
<p>YOUR_REVIEW_TEXT_1</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text8 "$(cat <<'EOF'
<p>YOUR_REVIEWER_2</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text9 "$(cat <<'EOF'
<p>YOUR_REVIEW_TITLE_2</p>
EOF
)" --allow-root --path=/var/www/html
wp post meta update $PAGE_ID text10 "$(cat <<'EOF'
<p>YOUR_REVIEW_TEXT_2</p>
EOF
)" --allow-root --path=/var/www/html

IMG1=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/img7.jpg --porcelain --allow-root --path=/var/www/html)
IMG2=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/urara.png --porcelain --allow-root --path=/var/www/html)
IMG3=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/review1.jpg --porcelain --allow-root --path=/var/www/html)
IMG4=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/review2.jpg --porcelain --allow-root --path=/var/www/html)

wp eval "update_field('field_lesson_img1', $IMG1, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_lesson_img2', $IMG2, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_lesson_img3', $IMG3, $PAGE_ID);" --allow-root --path=/var/www/html
wp eval "update_field('field_lesson_img4', $IMG4, $PAGE_ID);" --allow-root --path=/var/www/html

PAGE_ID=$(wp post create --post_type=page \
    --post_title='Profile' \
    --post_name='profile' \
    --post_status=publish --porcelain --allow-root --path=/var/www/html)

wp post meta update $PAGE_ID text1 "$(cat <<'EOF'
<div>YOUR_PROFILE_TEXT</div>
EOF
)" --allow-root --path=/var/www/html

IMG1=$(wp media import /var/www/html/wp-content/themes/onlineprofiletheme/assets/images/img6.jpg --porcelain --allow-root --path=/var/www/html)

wp eval "update_field('field_profile_img1', $IMG1, $PAGE_ID);" --allow-root --path=/var/www/html

wp post create --post_type=page \
    --post_title='Thanks' \
    --post_name='thanks' \
    --post_status=publish --allow-root --path=/var/www/html 2>/dev/null || true

echo "✓ Pages created!"

# ACF JSON内のページIDプレースホルダーを実際のIDで置換
echo "[8.5/15] Updating ACF JSON with actual page IDs..."

# ページリスト定義（案件ごとに変更）
PAGES="contact gallery home lesson profile"

# ループでID取得と置換
for page in $PAGES; do
    PAGE_ID=$(wp post list --post_type=page --name=$page --field=ID --allow-root --path=/var/www/html 2>/dev/null || echo "0")
    PAGE_UPPER=$(echo "$page" | tr '[:lower:]' '[:upper:]')
    sed -i "s/___PAGE_ID_${PAGE_UPPER}___/$PAGE_ID/g" /var/www/html/wp-content/themes/$THEME_NAME/acf-json/group_$page.json
    echo "  → $page: ID=$PAGE_ID"
done

# JSONを再度DBにインポート（ページIDが正しく設定された状態で）
wp eval-file /var/www/html/import-acf-json.php --allow-root --path=/var/www/html 2>&1 || echo "ACF re-import failed"

echo "✓ ACF JSON updated with page IDs!"

# カテゴリ作成
echo "[9/15] Creating categories..."
if ! wp term list category --field=name --allow-root --path=/var/www/html | grep -q "^News$"; then
    wp term create category 'News' --allow-root --path=/var/www/html
fi
if ! wp term list category --field=name --allow-root --path=/var/www/html | grep -q "^Concert$"; then
    wp term create category 'Concert' --allow-root --path=/var/www/html
fi

echo "✓ Categories created!"

# カテゴリIDを取得
NEWS_CAT_ID=$(wp term list category --field=term_id --name='News' --allow-root --path=/var/www/html 2>/dev/null || echo "")
CONCERT_CAT_ID=$(wp term list category --field=term_id --name='Concert' --allow-root --path=/var/www/html 2>/dev/null || echo "")
UNCAT_ID=$(wp term list category --field=term_id --name='Uncategorized' --allow-root --path=/var/www/html 2>/dev/null || echo "1")

# サンプル投稿作成（Newsカテゴリ：3件）
echo "[10/15] Creating News posts..."
if [ ! -z "$NEWS_CAT_ID" ]; then
    for i in {1..3}; do
        wp post create \
            --post_title="News Sample ${i}" \
            --post_content="これはNewsカテゴリのサンプル投稿${i}です。" \
            --post_category=$NEWS_CAT_ID \
            --post_status=publish \
            --allow-root \
            --path=/var/www/html 2>/dev/null || true
    done
fi

# サンプル投稿作成（Concertカテゴリ：3件）
echo "[11/15] Creating Concert posts..."
if [ ! -z "$CONCERT_CAT_ID" ]; then
    for i in {1..3}; do
        wp post create \
            --post_title="Concert Sample ${i}" \
            --post_content="これはConcertカテゴリのサンプル投稿${i}です。" \
            --post_category=$CONCERT_CAT_ID \
            --post_status=publish \
            --allow-root \
            --path=/var/www/html 2>/dev/null || true
    done
fi

# サンプル投稿作成（未分類：3件）
echo "[12/15] Creating Uncategorized posts..."
if [ ! -z "$UNCAT_ID" ]; then
    for i in {1..3}; do
        wp post create \
            --post_title="Uncategorized Sample ${i}" \
            --post_content="これは未分類のサンプル投稿${i}です。" \
            --post_category=$UNCAT_ID \
            --post_status=publish \
            --allow-root \
            --path=/var/www/html 2>/dev/null || true
    done
fi

echo "✓ Sample posts created!"

# 表示設定
echo "[13/15] Configuring display settings..."

# ホームページIDを取得
HOME_PAGE_ID=$(wp post list --post_type=page --name=home --field=ID --allow-root --path=/var/www/html 2>/dev/null || echo "")
BLOG_PAGE_ID=$(wp post list --post_type=page --name=blog --field=ID --allow-root --path=/var/www/html 2>/dev/null || echo "")

if [ ! -z "$HOME_PAGE_ID" ] && [ ! -z "$BLOG_PAGE_ID" ]; then
    wp option update show_on_front 'page' --allow-root --path=/var/www/html
    wp option update page_on_front $HOME_PAGE_ID --allow-root --path=/var/www/html
    wp option update page_for_posts $BLOG_PAGE_ID --allow-root --path=/var/www/html
    echo "✓ Homepage set to 'home', blog page set to 'All'"
fi

# サイトアイコン設定
ICON_PATH="/var/www/html/wp-content/themes/$THEME_NAME/assets/images/site-icon.png"
if [ -f "$ICON_PATH" ]; then
    ICON_ID=$(wp media import "$ICON_PATH" --porcelain --allow-root --path=/var/www/html)
    wp option update site_icon $ICON_ID --allow-root --path=/var/www/html
    echo "✓ Site icon set (ID: $ICON_ID)"
fi

# フィード設定
wp option update rss_use_excerpt 1 --allow-root --path=/var/www/html
# 検索エンジンブロック設定
wp option update blog_public 0 --allow-root --path=/var/www/html

echo "✓ Display settings configured!"

# ディスカッション設定
echo "[14/15] Configuring discussion settings..."
wp option update default_pingback_flag 0 --allow-root --path=/var/www/html
wp option update default_ping_status 'closed' --allow-root --path=/var/www/html
wp option update default_comment_status 'closed' --allow-root --path=/var/www/html

echo "✓ Discussion settings configured!"

# ユーザー設定（管理バーを無効化）
echo "[15/15] Configuring user settings..."
ADMIN_USER_ID=$(wp user get "${WP_ADMIN_USER}" --field=ID --allow-root --path=/var/www/html 2>/dev/null || echo "")
if [ ! -z "$ADMIN_USER_ID" ]; then
    wp user meta update $ADMIN_USER_ID show_admin_bar_front false --allow-root --path=/var/www/html
    echo "✓ Admin toolbar disabled for ${WP_ADMIN_USER}"
fi

echo "=========================================="
echo "✓ WordPress initialization completed!"
echo "=========================================="
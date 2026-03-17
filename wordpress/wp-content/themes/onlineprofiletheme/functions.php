<?php
// セキュリティ: WPバージョン非表示
remove_action('wp_head', 'wp_generator');
// セキュリティ: REST API linkヘッダー非表示
remove_action('template_redirect', 'rest_output_link_header', 11);
remove_action('wp_head', 'rest_output_link_wp_head', 10);

add_action('wp_enqueue_scripts', function () {
    $ver = wp_get_theme()->get('Version');

    // CSSは Tailwind(reset含むから) → main の順
    wp_enqueue_style('theme-tailwind', get_theme_file_uri('assets/css/output.css'), [], $ver);
    wp_enqueue_style('theme-main', get_theme_file_uri('assets/css/main.css'), ['theme-tailwind'], $ver);
    wp_enqueue_style('google-fonts-css', 'https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@100..900&family=Cormorant+Garamond:ital,wght@0,300..700;1,300..700&family=Noto+Serif+JP:wght@200..900&family=Parisienne&family=Philosopher:ital,wght@0,400;0,700;1,400;1,700&family=Dynalight&family=Ballet:opsz@16..72&family=Tangerine:wght@400;700&family=Cinzel:wght@400..900&family=Italianno&family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&family=Lora:ital,wght@0,400..700;1,400..700&family=Pinyon+Script&family=Playfair+Display:ital,wght@0,400..900;1,400..900&display=swap', [], null);

    // モジュールはエントリだけ enqueue（相対importはブラウザ解決）
    wp_enqueue_script('theme-script', get_theme_file_uri('assets/js/script.js'), [], $ver, true);

    // CF7送信成功時にサンクスページへリダイレクト
    wp_add_inline_script('theme-script', "
    document.addEventListener('wpcf7mailsent', function(event) {
        setTimeout(function() {
            location = '/thanks/';
        }, 1000);
    }, false);
");
}, 10);

// PHP→JSデータ受け渡しは head に先出し
// google fontのpreconnect先に出力するため優先度1
// JS側ではwindow.themeData.themeUriでアクセスできる
add_action('wp_head', function () {
    wp_print_inline_script_tag(
        'window.themeData = ' . wp_json_encode([
            'themeUri' => get_theme_file_uri(),
        ]) . ';'
    );
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">';
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>';
}, 1);

// クエリ実行前設定
// 管理画面でposts_per_page設定もできるが、全てのページで同じ件数になってしまう。
// ここではcategoryページを設定してる。
function set_category_posts_per_page($query) {
    if (!is_admin() && $query->is_main_query() && $query->is_category()) {
        $query->set('posts_per_page', 10);
    }
}
add_action('pre_get_posts', 'set_category_posts_per_page');

// アイキャッチ画像機能ON
add_action('after_setup_theme', function () {
  add_theme_support('post-thumbnails');   
});

// youtube埋め込み遅延処理
add_filter('oembed_result', function($html) {
    if (strpos($html, '<iframe') !== false) {
        $html = str_replace('<iframe', '<iframe loading="lazy"', $html);
    }
    return $html;
}, 10, 1);


/* ================================================ */
/* 管理画面から画像・テキスト・動画やSNSを保存可能にする*/
/* ================================================ */

/*  自作カスタムエディタ */
/* ================================================ */

/* ==================画像保存================= */

// WP標準メディアライブラリの有効化
add_action('admin_enqueue_scripts', function($hook) {
    if ($hook == 'post.php' || $hook == 'post-new.php') {
        wp_enqueue_media(); // WordPress標準メディアライブラリ
    }
});

// 画像編集用ショートコード登録
for ($i = 1; $i <= 10; $i++) {
    add_shortcode("img_{$i}", function($atts, $content, $tag) {
        $num = str_replace('img_', '', $tag);
        $img_id = get_post_meta(get_the_ID(), "_img_{$num}", true);
        return $img_id ? wp_get_attachment_image($img_id, 'full') : '';
    });
}

// メタボックス追加(数指定可)
add_action('add_meta_boxes', function() {
    add_meta_box('custom_images', 'カスタム画像設定', function($post) {
        $img_count = get_post_meta($post->ID, '_img_count', true);
        $img_count = $img_count !== '' ? intval($img_count) : 0; // デフォルト0
        
        // 使用数設定
        // テンプレートに編集可能にする埋込みコードを書く際は、必ず[text_1],[text_2]...[img_1],[img_2]...と昇順に埋め込み、管理画面で同数を設定してください。
        echo '<p><label>設定画像数(Max10): ';
        echo '<input type="number" name="img_count" style="width:60px;" value="' . $img_count . '" min="0" max="10"></label><small>　※ソースコードにある埋込コード数と一致させて下さい</small></p>';
        
        // 0より大きい場合のみアップローダー表示
        if ($img_count > 0) {
            for ($i = 1; $i <= $img_count; $i++) {
                $img_id = get_post_meta($post->ID, "_img_{$i}", true);
                echo "<div style='margin-bottom:4px;'><label style='font-weight: bold;'>画像{$i}　</label>";
                // 画像ID保存用
                echo "<input type='hidden' name='img_{$i}' id='img_{$i}' value='{$img_id}' />";

                // ボタンとプレビュー
                echo "<button type='button' class='upload-btn' data-target='img_{$i}'>画像選択</button>";
                echo "<button type='button' class='remove-btn' data-target='img_{$i}'>削除</button>";
                echo "<label>　embed:<code>echo do_shortcode('[img_{$i}]');</code></label></div>";
                echo "<div class='preview-{$i}'>";
                if ($img_id) echo wp_get_attachment_image($img_id, 'thumbnail');
                echo "</div>";
                echo '<hr>';
            }
        
            // JavaScript（WordPress標準機能使用）
            ?>
            <script>
            jQuery(document).ready(function($) {

                // 画像選択
                $('.upload-btn').click(function(e) {
                    e.preventDefault();
                    var target = $(this).data('target');
                    var mediaUploader = wp.media({
                        title: '画像を選択',
                        button: { text: '選択' },
                        multiple: false
                    });
                    mediaUploader.on('select', function() {
                        var attachment = mediaUploader.state().get('selection').first().toJSON();
                        $('#' + target).val(attachment.id);
                        $('.preview-' + target.replace('img_', '')).html('<img src="' + attachment.sizes.thumbnail.url + '" />');
                    });                
                    mediaUploader.open();
                });

                // 画像削除
                $('.remove-btn').click(function(e) {
                    e.preventDefault();
                    var target = $(this).data('target');
                    $('#' + target).val('');
                    $('.preview-' + target.replace('img_', '')).html('');
                });
            });
            </script>
            <?php
        }
    }, 'page');
});

// 画像保存処理
add_action('save_post', function($post_id) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    
    // 現在の設定数を取得
    $old_img_count = get_post_meta($post_id, '_img_count', true) ?: 0;
    $new_img_count = isset($_POST['img_count']) ? intval($_POST['img_count']) : 0;
    
    // 新しい数を保存
    update_post_meta($post_id, '_img_count', $new_img_count);
    
    // 画像保存
    for ($i = 1; $i <= $new_img_count; $i++) {
        if (isset($_POST["img_{$i}"])) {
            update_post_meta($post_id, "_img_{$i}", $_POST["img_{$i}"]);
        }
    }
    
    // 👇 範囲外になったデータを削除
    if ($new_img_count < $old_img_count) {
        for ($i = $new_img_count + 1; $i <= $old_img_count; $i++) {
            delete_post_meta($post_id, "_img_{$i}");
        }
    }
});


/* ========== テキスト保存 ========== */

// テキスト編集用ショートコード登録
for ($i = 1; $i <= 10; $i++) {
    add_shortcode("text_{$i}", function($atts, $content, $tag) {
        $num = str_replace('text_', '', $tag);
        $text_content = get_post_meta(get_the_ID(), "_text_{$num}", true);
        if (!$text_content) return '';
        // HTMLタグをそのまま出力（wp_ksesでフィルタリング）
        return wp_kses_post($text_content);
    });
}

// メタボックス追加
add_action('add_meta_boxes', function() {
    add_meta_box('custom_texts', 'カスタムテキスト設定', function($post) {
        $text_count = get_post_meta($post->ID, '_text_count', true);
        $text_count = $text_count !== '' ? intval($text_count) : 0;
        
        echo '<p><label>設定テキスト数(Max10): ';
        echo '<input type="number" name="text_count" style="width:60px;" value="' . $text_count . '" min="0" max="10"></label><small>　※ソースコードにある埋込コード数と一致させて下さい</small></p>';
        
        if ($text_count > 0) {
            for ($i = 1; $i <= $text_count; $i++) {
                $text_content = get_post_meta($post->ID, "_text_{$i}", true);
                echo "<div style='margin-bottom:20px;'>";
                echo "<label style='font-weight:bold;'>テキスト{$i}</label>　embed:<code>echo do_shortcode('[text_{$i}]');</code>";
                
                // エディタの設定はTinyMCEグローバル設定で
                wp_editor($text_content, "text_{$i}", array(
                    'textarea_name' => "text_{$i}",
                    'media_buttons' => false,
                    'textarea_rows' => 5,
                    'teeny' => false,
                ));
                echo "</div><hr>";
            }
        }
    }, 'page');
});

// テキスト保存処理（HTMLタグ許可版）
add_action('save_post', function($post_id) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;
    
    $old_text_count = get_post_meta($post_id, '_text_count', true) ?: 0;
    $new_text_count = isset($_POST['text_count']) ? intval($_POST['text_count']) : 0;
    
    update_post_meta($post_id, '_text_count', $new_text_count);
    
    // テキスト保存（HTMLタグを含む）
    for ($i = 1; $i <= $new_text_count; $i++) {
        if (isset($_POST["text_{$i}"])) {
            // wp_ksesでフィルタリングしてから保存
            $content = wp_kses_post(wp_unslash($_POST["text_{$i}"]));
            update_post_meta($post_id, "_text_{$i}", $content);
        }
    }
    
    // 範囲外削除
    if ($new_text_count < $old_text_count) {
        for ($i = $new_text_count + 1; $i <= $old_text_count; $i++) {
            delete_post_meta($post_id, "_text_{$i}");
        }
    }
});

// グローバルTinyMCE設定（システムメイン＋自作のエディタ設定）
add_filter('tiny_mce_before_init', 'custom_tinymce_config');
// ACFのWYSIWYGエディタ
// add_filter('acf/fields/wysiwyg/tinymce', 'custom_tinymce_config');
// エディタのカスタム設定
function custom_tinymce_config($initArray) {
    $initArray['toolbar_mode'] = 'wrap';
    $initArray['toolbar1'] = 'formatselect fontsizeselect | bold italic underline strikethrough | forecolor backcolor | alignleft aligncenter alignright alignjustify | bullist numlist | outdent indent | link unlink | removeformat | undo redo';
    $initArray['toolbar2'] = ''; //toolbar2がないと、TinyMCEが勝手にデフォルトのツールバーである３行目を追加してくる！
    $initArray['fontsize_formats'] = '10px 12px 14px 16px 18px 20px 24px 28px 32px 36px 48px 60px 72px';
    $initArray['block_formats'] = '段落=p;見出し1=h1;見出し2=h2;見出し3=h3;見出し4=h4;見出し5=h5;見出し6=h6;整形済み=pre';
    $initArray['height'] = 300;
    $initArray['textcolor_map'] = '["000000", "Black","993300", "Burnt orange","003300", "Dark green","000080", "Navy Blue","333399", "Indigo","800000", "Maroon","FF6600", "Orange","808000", "Olive","008000", "Green","008080", "Teal","0000FF", "Blue","666699", "Grayish blue","808080", "Gray","FF0000", "Red","FF9900", "Amber","99CC00", "Yellow green","33CCCC", "Turquoise","3366FF", "Royal blue","800080", "Purple","999999", "Medium gray","FF00FF", "Magenta","FFCC00", "Gold","FFFF00", "Yellow","00FF00", "Lime","00FFFF", "Aqua","00CCFF", "Sky blue","993366", "Red violet","FFFFFF", "White","FF99CC", "Pink","CCFFCC", "Pale green","CCFFFF", "Pale cyan","99CCFF", "Light sky blue","CC99FF", "Plum","d7d2de", "main2", "69113c", "accent", "ebb4b2", "main1", "ffe9dc", "base", "886b5e", "deco1", "d6af9e", "deco2", 
    ]';
    
    // wpautop完全制御
    $initArray['wpautop'] = false;
    return $initArray;

    // 空白改行と行頭スペースを維持しつつ、＆nbspの出現自力では抑えられなかったため、「Advanced Editor Tools」で対応する。以下は試みた設定調整。
    // $initArray['tadv_noautop'] = true;
    // $initArray['entity_encoding'] = 'named'; // 'raw'ではなく'named'
    // $initArray['entities'] = '160,nbsp,38,amp,60,lt,62,gt'; //38, ampがあると＆ampが出現する
    // $initArray['extended_valid_elements'] = 'span[*],div[*],p[*]';
    // $initArray['keep_styles'] = true;
}
add_filter('tiny_mce_before_init', 'custom_tinymce_config');


/* ==============メディア埋込み============= */

// 埋め込みコード用ショートコード登録
for ($i = 1; $i <= 10; $i++) {
    add_shortcode("media_{$i}", function($atts, $content, $tag) {
        $num = str_replace('media_', '', $tag);
        $media_code = get_post_meta(get_the_ID(), "_media_{$num}", true);
        // サニタイズせずそのまま出力
        return $media_code ?: '';
    });
}

// メタボックス追加
add_action('add_meta_boxes', function() {
    add_meta_box('custom_medias', 'カスタムメディア設定', function($post) {
        $media_count = get_post_meta($post->ID, '_media_count', true);
        $media_count = $media_count !== '' ? intval($media_count) : 0;
        
        echo '<p><label>設定メディア数(Max10): ';
        echo '<input type="number" name="media_count" style="width:60px;" value="' . $media_count . '" min="0" max="10"></label><small>　※ソースコードにある埋込コード数と一致させて下さい</small></p>';
        
        if ($media_count > 0) {
            for ($i = 1; $i <= $media_count; $i++) {
                $media_content = get_post_meta($post->ID, "_media_{$i}", true);
                echo "<label style='font-weight:bold;'>メディア{$i}</label>　embed:<code>echo do_shortcode('[media_{$i}]');</code><br>";
                echo "<textarea name='media_{$i}' rows='8' style='width:100%; style='margin-bottom:20px;'>" . esc_textarea($media_content) . "</textarea><br><hr>";
            }
        }
    }, 'page');
});

// 保存処理
add_action('save_post', function($post_id) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return; // 権限チェック
    
    $old_media_count = get_post_meta($post_id, '_media_count', true) ?: 0;
    $new_media_count = isset($_POST['media_count']) ? intval($_POST['media_count']) : 0;
    
    update_post_meta($post_id, '_media_count', $new_media_count);
    
    // 埋め込みコード保存（サニタイズなし）
    for ($i = 1; $i <= $new_media_count; $i++) {
        if (isset($_POST["media_{$i}"])) {
            update_post_meta($post_id, "_media_{$i}", wp_unslash($_POST["media_{$i}"]));
        }
    }
    
    // 範囲外削除
    if ($new_media_count < $old_media_count) {
        for ($i = $new_media_count + 1; $i <= $old_media_count; $i++) {
            delete_post_meta($post_id, "_media_{$i}");
        }
    }
});
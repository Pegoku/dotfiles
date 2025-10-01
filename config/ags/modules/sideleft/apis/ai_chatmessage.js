const { Gdk, Gio, GLib, Gtk } = imports.gi;
import GtkSource from "gi://GtkSource?version=3.0";
import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { Box, Button, Label, Icon, Scrollable, Stack, Revealer } = Widget;
const { execAsync, exec } = Utils;
import { MaterialIcon } from '../../.commonwidgets/materialicon.js';
import md2pango from '../../.miscutils/md2pango.js';
import { darkMode } from "../../.miscutils/system.js";
import { setupCursorHoverInfo } from '../../.widgetutils/cursorhover.js';

const LATEX_DIR = `${GLib.get_user_cache_dir()}/ags/media/latex`;
const CUSTOM_SOURCEVIEW_SCHEME_PATH = `${App.configDir}/assets/themes/sourceviewtheme${darkMode.value ? '' : '-light'}.xml`;
const CUSTOM_SCHEME_ID = `custom${darkMode.value ? '' : '-light'}`;
const USERNAME = GLib.get_user_name();

/////////////////////// Custom source view colorscheme /////////////////////////

function loadCustomColorScheme(filePath) {
    // Read the XML file content
    const file = Gio.File.new_for_path(filePath);
    const [success, contents] = file.load_contents(null);

    if (!success) {
        logError('Failed to load the XML file.');
        return;
    }

    // Parse the XML content and set the Style Scheme
    const schemeManager = GtkSource.StyleSchemeManager.get_default();
    schemeManager.append_search_path(file.get_parent().get_path());
}
loadCustomColorScheme(CUSTOM_SOURCEVIEW_SCHEME_PATH);

//////////////////////////////////////////////////////////////////////////////

function substituteLang(str) {
    const subs = [
        { from: 'javascript', to: 'js' },
        { from: 'bash', to: 'sh' },
    ];
    for (const { from, to } of subs) {
        if (from === str) return to;
    }
    return str;
}

const HighlightedCode = (content, lang) => {
    const buffer = new GtkSource.Buffer();
    const sourceView = new GtkSource.View({
        buffer: buffer,
        wrap_mode: Gtk.WrapMode.NONE
    });
    const langManager = GtkSource.LanguageManager.get_default();
    let displayLang = langManager.get_language(substituteLang(lang)); // Set your preferred language
    if (displayLang) {
        buffer.set_language(displayLang);
    }
    const schemeManager = GtkSource.StyleSchemeManager.get_default();
    buffer.set_style_scheme(schemeManager.get_scheme(CUSTOM_SCHEME_ID));
    buffer.set_text(content, -1);
    return sourceView;
}

const TextBlock = (content = '') => Label({
    hpack: 'fill',
    className: 'txt sidebar-chat-txtblock sidebar-chat-txt',
    useMarkup: true,
    xalign: 0,
    wrap: true,
    selectable: true,
    label: content,
});

Utils.execAsync(['bash', '-c', `rm -rf ${LATEX_DIR}`])
    .then(() => Utils.execAsync(['bash', '-c', `mkdir -p ${LATEX_DIR}`]))
    .catch(print);
const Latex = (content = '') => {
    const latexViewArea = Box({
        // vscroll: 'never',
        // hscroll: 'automatic',
        // homogeneous: true,
        attribute: {
            render: async (self, text) => {
                if (text.length == 0) return;
                const styleContext = self.get_style_context();
                const fontSize = styleContext.get_property('font-size', Gtk.StateFlags.NORMAL);

                const timeSinceEpoch = Date.now();
                const fileName = `${timeSinceEpoch}.tex`;
                const outFileName = `${timeSinceEpoch}-symbolic.svg`;
                const outIconName = `${timeSinceEpoch}-symbolic`;
                const scriptFileName = `${timeSinceEpoch}-render.sh`;
                const filePath = `${LATEX_DIR}/${fileName}`;
                const outFilePath = `${LATEX_DIR}/${outFileName}`;
                const scriptFilePath = `${LATEX_DIR}/${scriptFileName}`;

                Utils.writeFile(text, filePath).catch(print);
                // Since MicroTex doesn't support file path input properly, we gotta cat it
                // And escaping such a command is a fucking pain so I decided to just generate a script
                // Note: MicroTex doesn't support `&=`
                // You can add this line in the middle for debugging: echo "$text" > ${filePath}.tmp
                const renderScript = `#!/usr/bin/env bash
text=$(cat ${filePath} | sed 's/$/ \\\\\\\\/g' | sed 's/&=/=/g')
cd /opt/MicroTeX
./LaTeX -headless -input="$text" -output=${outFilePath} -textsize=${fontSize * 1.1} -padding=0 -maxwidth=${latexViewArea.get_allocated_width() * 0.85} > /dev/null 2>&1
sed -i 's/fill="rgb(0%, 0%, 0%)"/style="fill:#000000"/g' ${outFilePath}
sed -i 's/stroke="rgb(0%, 0%, 0%)"/stroke="${darkMode.value ? '#ffffff' : '#000000'}"/g' ${outFilePath}
`;
                Utils.writeFile(renderScript, scriptFilePath).catch(print);
                Utils.exec(`chmod a+x ${scriptFilePath}`)
                Utils.timeout(100, () => {
                    Utils.exec(`bash ${scriptFilePath}`);
                    Gtk.IconTheme.get_default().append_search_path(LATEX_DIR);

                    self.child?.destroy();
                    self.child = Gtk.Image.new_from_icon_name(outIconName, 0);
                })
            }
        },
        setup: (self) => self.attribute.render(self, content).catch(print),
    });
    const wholeThing = Box({
        className: 'sidebar-chat-latex',
        homogeneous: true,
        attribute: {
            'updateText': (text) => {
                latexViewArea.attribute.render(latexViewArea, text).catch(print);
            }
        },
        children: [Scrollable({
            vscroll: 'never',
            hscroll: 'automatic',
            child: latexViewArea
        })]
    })
    return wholeThing;
}

const CodeBlock = (content = '', lang = 'txt') => {
    if (lang == 'tex' || lang == 'latex') {
        return Latex(content);
    }
    const topBar = Box({
        className: 'sidebar-chat-codeblock-topbar',
        children: [
            Label({
                label: lang,
                className: 'sidebar-chat-codeblock-topbar-txt',
            }),
            Box({
                hexpand: true,
            }),
            Button({
                className: 'sidebar-chat-codeblock-topbar-btn',
                child: Box({
                    className: 'spacing-h-5',
                    children: [
                        MaterialIcon('content_copy', 'small'),
                        Label({
                            label: 'Copy',
                        })
                    ]
                }),
                onClicked: (self) => {
                    const buffer = sourceView.get_buffer();
                    const copyContent = buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter(), false); // TODO: fix this
                    execAsync([`wl-copy`, `${copyContent}`]).catch(print);
                },
            }),
        ]
    })
    // Source view
    const sourceView = HighlightedCode(content, lang);

    const codeBlock = Box({
        attribute: {
            'updateText': (text) => {
                sourceView.get_buffer().set_text(text, -1);
            }
        },
        className: 'sidebar-chat-codeblock',
        vertical: true,
        children: [
            topBar,
            Box({
                className: 'sidebar-chat-codeblock-code',
                homogeneous: true,
                children: [Scrollable({
                    vscroll: 'never',
                    hscroll: 'automatic',
                    child: sourceView,
                })],
            })
        ]
    })

    // const schemeIds = styleManager.get_scheme_ids();

    // print("Available Style Schemes:");
    // for (let i = 0; i < schemeIds.length; i++) {
    //     print(schemeIds[i]);
    // }
    return codeBlock;
}

const Divider = () => Box({
    className: 'sidebar-chat-divider',
})

const MessageContent = (content) => {
    const contentBox = Box({
        vertical: true,
        attribute: {
            'fullUpdate': (self, content, useCursor = false) => {
                // Clear and add first text widget
                const children = contentBox.get_children();
                for (let i = 0; i < children.length; i++) {
                    const child = children[i];
                    child.destroy();
                }
                contentBox.add(TextBlock())
                // Loop lines. Put normal text in markdown parser
                // and put code into code highlighter (TODO)
                let lines = content.split('\n');
                let lastProcessed = 0;
                let inCode = false;
                for (const [index, line] of lines.entries()) {
                    // Code blocks
                    const codeBlockRegex = /^\s*```([a-zA-Z0-9]+)?\n?/;
                    if (codeBlockRegex.test(line)) {
                        const kids = self.get_children();
                        const lastLabel = kids[kids.length - 1];
                        const blockContent = lines.slice(lastProcessed, index).join('\n');
                        if (!inCode) {
                            lastLabel.label = md2pango(blockContent);
                            contentBox.add(CodeBlock('', codeBlockRegex.exec(line)[1]));
                        }
                        else {
                            lastLabel.attribute.updateText(blockContent);
                            contentBox.add(TextBlock());
                        }

                        lastProcessed = index + 1;
                        inCode = !inCode;
                    }
                    // Breaks
                    const dividerRegex = /^\s*---/;
                    if (!inCode && dividerRegex.test(line)) {
                        const kids = self.get_children();
                        const lastLabel = kids[kids.length - 1];
                        const blockContent = lines.slice(lastProcessed, index).join('\n');
                        lastLabel.label = md2pango(blockContent);
                        contentBox.add(Divider());
                        contentBox.add(TextBlock());
                        lastProcessed = index + 1;
                    }
                }
                if (lastProcessed < lines.length) {
                    const kids = self.get_children();
                    const lastLabel = kids[kids.length - 1];
                    let blockContent = lines.slice(lastProcessed, lines.length).join('\n');
                    if (!inCode)
                        lastLabel.label = `${md2pango(blockContent)}${useCursor ? userOptions.ai.writingCursor : ''}`;
                    else
                        lastLabel.attribute.updateText(blockContent);
                }
                // Debug: plain text
                // contentBox.add(Label({
                //     hpack: 'fill',
                //     className: 'txt sidebar-chat-txtblock sidebar-chat-txt',
                //     useMarkup: false,
                //     xalign: 0,
                //     wrap: true,
                //     selectable: true,
                //     label: '------------------------------\n' + md2pango(content),
                // }))
                contentBox.show_all();
            }
        }
    });
    contentBox.attribute.fullUpdate(contentBox, content, false);
    return contentBox;
}

export const ChatMessage = (message, modelName = 'Model') => {
    const TextSkeleton = (extraClassName = '') => Box({
        className: `sidebar-chat-message-skeletonline ${extraClassName}`,
    })

    // Helper to extract <think>...</think> content (if present) and the main answer
    const parseThinking = (raw) => {
        if (!raw) return { answer: '', thinking: '' };
        const regex = /<think>([\s\S]*?)<\/think>/i;
        const match = raw.match(regex);
        if (!match) return { answer: raw, thinking: '' };
        const thinking = match[1].trim();
        const answer = raw.replace(regex, '').trimStart();
        return { answer, thinking };
    };

    // Initial parse
    let { answer: initialAnswer, thinking: initialThinking } = parseThinking(message.content);

    const messageContentBox = MessageContent(initialAnswer);
    const thinkingContentBox = MessageContent(initialThinking);

    // Thinking collapsible UI (hidden if no thinking block)
    const ARROW_CLOSED = '▶'; // closed state (like HTML <summary>)
    const ARROW_OPEN = '▼';   // open state
    const thinkingArrow = Label({ className: 'txt-smallie txt-subtext', label: ARROW_CLOSED });
    const thinkingHeader = Button({
        className: 'sidebar-chat-thinking-toggle txt-subtext txt-smallie',
        visible: initialThinking.length > 0,
        child: Box({ className: 'spacing-h-5', children: [
            Label({ label: 'Thinking', className: 'txt-subtext txt-smallie' }),
            thinkingArrow,
        ] }),
        onClicked: (self) => {
            thinkingRevealer.revealChild = !thinkingRevealer.revealChild;
            thinkingArrow.label = thinkingRevealer.revealChild ? ARROW_OPEN : ARROW_CLOSED;
        },
        setup: setupCursorHoverInfo,
    });
    const thinkingRevealer = Revealer({
        revealChild: false,
        transition: 'slide_down',
        transitionDuration: userOptions.animations.durationLarge,
        child: Box({ className: 'sidebar-chat-thinking-area', children: [thinkingContentBox] }),
        visible: initialThinking.length > 0,
    });

    // Animated dots while thinking
    const AnimatedDots = () => {
        const frames = [
            '<span rise="-4000">•</span>  •  <span rise="4000">•</span>',
            '•  <span rise="-4000">•</span>  <span rise="4000">•</span>',
            '<span rise="4000">•</span>  •  <span rise="-4000">•</span>',
            '•  <span rise="4000">•</span>  <span rise="-4000">•</span>',
        ];
        let i = 0;
        let timerId = 0;
        const dotLabel = Label({
            useMarkup: true,
            className: 'txt-subtext',
            label: frames[0],
        });
        const container = Box({
            homogeneous: true,
            children: [dotLabel],
            attribute: {
                start: () => {
                    if (timerId) return;
                    timerId = Utils.interval(180, () => {
                        i = (i + 1) % frames.length;
                        dotLabel.label = frames[i];
                    });
                },
                stop: () => {
                    if (!timerId) return;
                    Utils.clearInterval(timerId);
                    timerId = 0;
                }
            }
        });
        return container;
    };
    const messageLoadingDots = AnimatedDots();
    const messageArea = Stack({
        homogeneous: message.role !== 'user',
        transition: 'crossfade',
        transitionDuration: userOptions.animations.durationLarge,
        children: {
            'thinking': messageLoadingDots,
            'message': messageContentBox,
        },
        shown: message.thinking ? 'thinking' : 'message',
    });
    const metaLabel = Label({
        xalign: 0,
        className: 'txt-smallie txt-subtext',
        wrap: true,
        label: '',
        visible: false,
    });
    const copyBtn = Button({
        className: 'sidebar-chat-codeblock-topbar-btn',
        child: Box({
            className: 'spacing-h-5',
            children: [
                MaterialIcon('content_copy', 'small'),
                Label({ label: 'Copy' }),
            ]
        }),
        tooltipText: 'Copy message',
        onClicked: () => {
            const text = message?.content ?? '';
            execAsync(['wl-copy', text]).catch(print);
        },
    });
    const actionsBar = Box({
        className: 'spacing-h-5',
        children: [copyBtn],
        visible: message.role !== 'system' && Boolean(message.content),
    });
    const thisMessage = Box({
        className: 'sidebar-chat-message',
        homogeneous: true,
        children: [
            Box({
                vertical: true,
                children: [
                    Label({
                        hpack: 'start',
                        xalign: 0,
                        className: `txt txt-bold sidebar-chat-name sidebar-chat-name-${message.role == 'user' ? 'user' : 'bot'}`,
                        wrap: true,
                        useMarkup: true,
                        label: (message.role == 'user' ? USERNAME : modelName),
                    }),
                    Box({
                        homogeneous: true,
                        className: 'sidebar-chat-messagearea',
                        children: [messageArea]
                    }),
                    // Collapsible thinking trace (if provided by model)
                    thinkingHeader,
                    thinkingRevealer,
                    // Meta (tokens/time) and actions only for assistant
                    ...(message.role === 'user' ? [] : [metaLabel, actionsBar]),
                ],
                setup: (self) => self
                    .hook(message, (self, isThinking) => {
                        messageArea.shown = message.thinking ? 'thinking' : 'message';
                        if (message.thinking) messageLoadingDots.attribute.start();
                        else messageLoadingDots.attribute.stop();
                        // Remove cursor when done thinking
                        if (!message.thinking) {
                            // Re-render without writing cursor
                            const { answer, thinking } = parseThinking(message.content);
                            messageContentBox.attribute.fullUpdate(messageContentBox, answer, false);
                        }
                    }, 'notify::thinking')
                    .hook(message, (self) => { // Message update
                        const { answer, thinking } = parseThinking(message.content);
                        // Update main answer (cursor only while still thinking)
                        messageContentBox.attribute.fullUpdate(messageContentBox, answer, (message.role != 'user') && message.thinking);
                        // Update thinking section if appears later during stream
                        const hasThinking = thinking.length > 0;
                        thinkingHeader.visible = hasThinking;
                        thinkingRevealer.visible = hasThinking;
                        if (hasThinking) thinkingContentBox.attribute.fullUpdate(thinkingContentBox, thinking, false);
                        // Show or hide the actions bar when assistant content updates
                        actionsBar.visible = (message.role !== 'system') && !!message.content;
                    }, 'notify::content')
                    .hook(message, () => { // Meta update
                        if (message.role === 'user') return;
                        const meta = (message.meta || '').trim();
                        metaLabel.visible = meta.length > 0;
                        metaLabel.label = meta;
                    }, 'notify::meta')
                ,
            })
        ]
    });
    return thisMessage;
}

export const SystemMessage = (content, commandName, scrolledWindow) => {
    const messageContentBox = MessageContent(content);
    const thisMessage = Box({
        className: 'sidebar-chat-message',
        children: [
            Box({
                vertical: true,
                children: [
                    Label({
                        xalign: 0,
                        hpack: 'start',
                        className: 'txt txt-bold sidebar-chat-name sidebar-chat-name-system',
                        wrap: true,
                        label: `System  •  ${commandName}`,
                    }),
                    messageContentBox,
                ],
            })
        ],
    });
    return thisMessage;
}

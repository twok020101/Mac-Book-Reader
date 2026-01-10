import SwiftUI
import WebKit
import Combine

public struct EPUBPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        if let url = viewModel.currentChapterURL {
            EPUBWebView(
                viewModel: viewModel, 
                url: url, 
                currentSubPage: viewModel.currentSubPage,
                pendingFragment: viewModel.pendingScrollToFragment
            )
            .id(url) // Force reload when URL changes
        } else {
            if let error = viewModel.errorMessage {
                ContentUnavailableView("Error Loading Book", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if viewModel.isLoading {
                ProgressView("Opening Book...")
            } else {
                Text("Preparing Content...")
            }
        }
    }
}

// MARK: - NSViewRepresentable for WKWebView with Swift-controlled scrolling

struct EPUBWebView: NSViewRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let url: URL
    let currentSubPage: Int  // Explicit dependency for SwiftUI reactivity
    let pendingFragment: String?  // For sub-chapter anchor scrolling
    
    func makeNSView(context: Context) -> NSView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "pagination")
        contentController.add(context.coordinator, name: "textSelection")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Container view
        let container = NSView()
        container.wantsLayer = true
        container.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Store webView reference in coordinator
        context.coordinator.webView = webView
        
        // Load initial content
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let webView = context.coordinator.webView else { return }
        
        // Reload if URL changed
        if webView.url != url {
            print("DEBUG: Loading new chapter URL: \(url.lastPathComponent)")
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else if let fragment = pendingFragment {
            // Scroll to anchor within the page
            print("DEBUG: updateNSView - scrolling to fragment #\(fragment)")
            context.coordinator.scrollToFragment(fragment)
            // Clear the pending fragment
            DispatchQueue.main.async {
                self.viewModel.pendingScrollToFragment = nil
            }
        } else {
            // Same URL - only scroll if page actually changed
            if currentSubPage != context.coordinator.lastScrolledPage {
                print("DEBUG: updateNSView - scrolling from page \(context.coordinator.lastScrolledPage) to \(currentSubPage)")
                context.coordinator.scrollToPage(currentSubPage)
                context.coordinator.lastScrolledPage = currentSubPage
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // MARK: - Coordinator with Swift-controlled pagination
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: EPUBWebView
        weak var webView: WKWebView?
        
        private var frameObservation: NSKeyValueObservation?
        private var didInjectCSS = false
        var lastScrolledPage: Int = -1  // Track last scrolled page
        
        init(parent: EPUBWebView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            frameObservation?.invalidate()
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "pagination" {
                if let dict = message.body as? [String: Any],
                   let totalPages = dict["totalPages"] as? Int {
                    DispatchQueue.main.async {
                        self.parent.viewModel.totalSubPages = totalPages
                        print("DEBUG: Updated totalSubPages to \(totalPages)")
                        
                        // Apply pending page navigation NOW that we know totalSubPages
                        if let pendingPage = self.parent.viewModel.pendingPageIndex {
                            print("DEBUG: Applying pending page navigation to page \(pendingPage) (total: \(totalPages))")
                            // Ensure page is within bounds
                            let safePage = min(max(0, pendingPage), totalPages - 1)
                            self.parent.viewModel.currentSubPage = safePage
                            self.parent.viewModel.pendingPageIndex = nil
                            
                            // Scroll to the page and track it
                            self.scrollToPage(safePage)
                            self.lastScrolledPage = safePage
                            print("DEBUG: Scrolled and set lastScrolledPage to \(safePage)")
                        }
                    }
                }
            } else if message.name == "textSelection" {
                if let dict = message.body as? [String: Any],
                   let text = dict["text"] as? String {
                    DispatchQueue.main.async {
                        self.parent.viewModel.selectedText = text
                        print("DEBUG: Selected text: '\(text.prefix(50))...'")
                    }
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("DEBUG: WebView didFinish navigation")
            didInjectCSS = false
            injectPaginationCSS()
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Reset pagination state when new content loads
            DispatchQueue.main.async {
                self.parent.viewModel.totalSubPages = 1
                self.parent.viewModel.currentSubPage = 0
            }
        }
        
        // MARK: - CSS & JS Injection - Wrapper with Transform approach
        
        private func injectPaginationCSS() {
            guard let webView = webView, !didInjectCSS else { return }
            didInjectCSS = true
            
            // This approach:
            // 1. Wraps body content in a div#reader-wrapper
            // 2. Uses CSS columns on the wrapper
            // 3. Uses transform: translateX() to move between pages
            // This works because transform can move content even when overflow is hidden
            
            let js = """
            (function() {
                // CSS for multi-column layout with wrapper
                var css = `
                    html, body {
                        margin: 0 !important;
                        padding: 0 !important;
                        width: 100vw !important;
                        height: 100vh !important;
                        overflow: hidden !important;
                    }
                    #reader-wrapper {
                        height: calc(100vh - 80px) !important;
                        padding: 40px !important;
                        box-sizing: content-box !important;
                        
                        column-fill: auto !important;
                        column-gap: 80px !important;
                        
                        transition: transform 0.2s ease-out;
                    }
                    #reader-wrapper * {
                        max-width: 100% !important;
                    }
                    #reader-wrapper img {
                        max-height: 80vh !important;
                        object-fit: contain !important;
                    }
                `;
                
                // Add CSS
                var style = document.createElement('style');
                style.id = 'reader-style';
                style.innerHTML = css;
                document.head.appendChild(style);
                
                // Wrap body content if not already wrapped
                if (!document.getElementById('reader-wrapper')) {
                    var wrapper = document.createElement('div');
                    wrapper.id = 'reader-wrapper';
                    while (document.body.firstChild) {
                        wrapper.appendChild(document.body.firstChild);
                    }
                    document.body.appendChild(wrapper);
                }
                
                // Set column width based on viewport
                var viewWidth = window.innerWidth;
                var columnWidth = viewWidth - 80; // account for padding
                var wrapper = document.getElementById('reader-wrapper');
                wrapper.style.columnWidth = columnWidth + 'px';
                
                // Calculate page count after a brief delay for layout
                setTimeout(function() {
                    var scrollWidth = wrapper.scrollWidth;
                    var totalPages = Math.max(1, Math.ceil(scrollWidth / viewWidth));
                    
                    console.log('Pagination: scrollWidth=' + scrollWidth + ' viewWidth=' + viewWidth + ' totalPages=' + totalPages);
                    
                    window.webkit.messageHandlers.pagination.postMessage({
                        'totalPages': totalPages,
                        'scrollWidth': scrollWidth,
                        'viewWidth': viewWidth
                    });
                }, 300);
                
                // Expose scrollToPage function
                window.scrollToPage = function(pageIndex) {
                    var wrapper = document.getElementById('reader-wrapper');
                    if (!wrapper) return;
                    
                    var viewWidth = window.innerWidth;
                    var targetX = pageIndex * viewWidth;
                    
                    wrapper.style.transform = 'translateX(-' + targetX + 'px)';
                    console.log('Scrolled to page ' + pageIndex + ' (X: -' + targetX + ')');
                };
                
                // Handle resize
                window.addEventListener('resize', function() {
                    var wrapper = document.getElementById('reader-wrapper');
                    if (!wrapper) return;
                    
                    var viewWidth = window.innerWidth;
                    var columnWidth = viewWidth - 80;
                    wrapper.style.columnWidth = columnWidth + 'px';
                    
                    setTimeout(function() {
                        var scrollWidth = wrapper.scrollWidth;
                        var totalPages = Math.max(1, Math.ceil(scrollWidth / viewWidth));
                        window.webkit.messageHandlers.pagination.postMessage({
                            'totalPages': totalPages
                        });
                    }, 200);
                });
                
                // Text selection detection
                document.addEventListener('mouseup', function() {
                    setTimeout(function() {
                        var selectedText = window.getSelection().toString().trim();
                        if (selectedText && selectedText.length > 0) {
                            window.webkit.messageHandlers.textSelection.postMessage({
                                'text': selectedText
                            });
                        }
                    }, 10);
                });
                
                return { status: 'injected', viewWidth: viewWidth };
            })();
            """
            
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("DEBUG: CSS injection error: \(error.localizedDescription)")
                } else if let dict = result as? [String: Any] {
                    print("DEBUG: CSS injected successfully: \(dict)")
                }
            }
        }
        
        // MARK: - Swift-Controlled Scrolling via JS
        
        func scrollToPage(_ pageIndex: Int) {
            guard let webView = webView else {
                print("DEBUG: scrollToPage - webView is nil")
                return
            }
            
            let js = "window.scrollToPage && window.scrollToPage(\(pageIndex));"
            
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("DEBUG: scrollToPage error: \(error.localizedDescription)")
                } else {
                    print("DEBUG: scrollToPage(\(pageIndex)) executed")
                }
            }
        }
        
        func scrollToFragment(_ fragment: String) {
            guard let webView = webView else {
                print("DEBUG: scrollToFragment - webView is nil")
                return
            }
            
            // JavaScript to find element and calculate which page it's on
            // Uses element position relative to wrapper since we use CSS transform pagination
            let js = """
            (function() {
                var element = document.getElementById('\(fragment)') || document.querySelector('[name="\(fragment)"]');
                if (element) {
                    var wrapper = document.getElementById('reader-wrapper');
                    if (!wrapper) {
                        console.log('Fragment scroll failed: no reader-wrapper');
                        return { success: false, page: 0 };
                    }
                    
                    var pageWidth = window.innerWidth;
                    var wrapperRect = wrapper.getBoundingClientRect();
                    var rect = element.getBoundingClientRect();
                    
                    // Calculate element's X position relative to wrapper's original position
                    // wrapperRect.left accounts for any current transform, so we need to
                    // calculate the "untransformed" position
                    var currentTransform = wrapper.style.transform || '';
                    var currentOffset = 0;
                    var match = currentTransform.match(/translateX\\((-?\\d+)px\\)/);
                    if (match) {
                        currentOffset = parseInt(match[1]);
                    }
                    
                    // Element's absolute X from document start
                    var elementAbsoluteX = rect.left - wrapperRect.left - currentOffset;
                    var currentPage = Math.max(0, Math.floor(elementAbsoluteX / pageWidth));
                    
                    console.log('Fragment: ' + '\(fragment)' + ' elementX: ' + elementAbsoluteX + ' page: ' + currentPage);
                    
                    // Scroll to that page using our transform-based pagination
                    if (window.scrollToPage) {
                        window.scrollToPage(currentPage);
                    }
                    
                    return { success: true, page: currentPage };
                } else {
                    console.log('Fragment not found: \(fragment)');
                    return { success: false, page: 0 };
                }
            })();
            """
            
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("DEBUG: scrollToFragment error: \\(error.localizedDescription)")
                } else if let dict = result as? [String: Any],
                          let success = dict["success"] as? Bool,
                          let page = dict["page"] as? Int {
                    print("DEBUG: scrollToFragment('\\(fragment)') - success: \\(success), page: \\(page)")
                    
                    if success {
                        // Update currentSubPage to match the actual page the fragment is on
                        DispatchQueue.main.async {
                            self.parent.viewModel.currentSubPage = page
                            self.lastScrolledPage = page
                            print("DEBUG: Updated currentSubPage to \\(page) after fragment scroll")
                        }
                    }
                }
            }
        }
    }
}

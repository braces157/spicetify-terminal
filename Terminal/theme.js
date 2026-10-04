/* Terminal presentation hooks and reversible native window chrome. */
(() => {
  window.__terminalThemeCleanup?.();
  let restoreWindowChrome;
  let chromeRetry;
  let chromeAttempts = 0;
  let windowControlsVisible = false;
  const chromeState = () => {
    document.documentElement.dataset.tuiWindowControls = windowControlsVisible ? 'visible' : 'hidden';
  };
  const setupWindowChrome = () => {
    const native = window.Spicetify?.Platform?.NativeAPI;
    const control = window.Spicetify?.Platform?.ControlMessageAPI;
    if (!native?.setWindowButtonsVisibility || !control?.setTitlebarHeight) {
      if (++chromeAttempts < 100) chromeRetry = setTimeout(setupWindowChrome, 100);
      return;
    }
    const originalVisibility = native.setWindowButtonsVisibility;
    const originalHeight = control.setTitlebarHeight;
    let nativeHeight = 64;
    // Spotify can re-show buttons when panels close or the viewport zooms.
    // Keep these requests consistent with the user's F8 choice.
    const visibilityHook = function (show) {
      return originalVisibility.call(this, windowControlsVisible && show);
    };
    const heightHook = function (height) {
      nativeHeight = height;
      return originalHeight.call(this, windowControlsVisible ? 72 : 1);
    };
    native.setWindowButtonsVisibility = visibilityHook;
    control.setTitlebarHeight = heightHook;
    const applyChrome = () => {
      chromeState();
      Promise.all([
        originalHeight.call(control, windowControlsVisible ? 72 : 1),
        originalVisibility.call(native, windowControlsVisible),
      ]).catch(error => console.warn('[Terminal] Window chrome update failed', error));
    };
    const onChromeKey = event => {
      if (event.key !== 'F8' || event.repeat || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      windowControlsVisible = !windowControlsVisible;
      applyChrome();
    };
    const onFullscreen = () => { if (!document.fullscreenElement) applyChrome(); };
    document.addEventListener('keydown', onChromeKey, true);
    document.addEventListener('fullscreenchange', onFullscreen);
    restoreWindowChrome = () => {
      document.removeEventListener('keydown', onChromeKey, true);
      document.removeEventListener('fullscreenchange', onFullscreen);
      if (native.setWindowButtonsVisibility === visibilityHook) native.setWindowButtonsVisibility = originalVisibility;
      if (control.setTitlebarHeight === heightHook) control.setTitlebarHeight = originalHeight;
      delete document.documentElement.dataset.tuiWindowControls;
      Promise.all([
        originalHeight.call(control, nativeHeight),
        originalVisibility.call(native, true),
      ]).catch(error => console.warn('[Terminal] Window chrome restore failed', error));
    };
    applyChrome();
  };
  setupWindowChrome();
  let queued = false;
  let volumeInput;
  let volumeLabel;
  let lastVolume = '';
  const updateVolume = () => {
    if (!volumeInput || !volumeLabel) return;
    const level = window.Spicetify?.Player?.getVolume?.();
    const next = `${Math.round((typeof level === 'number' ? level : Number(volumeInput.value)) * 100)}%`;
    if (lastVolume !== next) { volumeLabel.textContent = next; lastVolume = next; }
  };
  const set = (el, key, value) => { if (el && el.dataset[key] !== value) el.dataset[key] = value; };
  function decorate() {
    const nav = document.querySelector('.Root__globalNav');
    set(nav, 'tuiPane', ' NAV ');
    if (nav) {
      const groups = [...nav.children].filter(el => el.tagName === 'DIV');
      groups.forEach((el, i) => set(el, 'tuiNavGroup', ['left', 'search', 'right'][i] || 'extra'));
      set(nav.querySelector('button[aria-label="Home"]')?.parentElement, 'tuiHomeGroup', 'true');
      nav.querySelectorAll('.main-globalNav-historyButtons button,.main-globalNav-navLink,.main-globalNav-contentRight button,form button').forEach(el => {
        if (!el.closest('[role="dialog"],[role="listbox"]') && !el.getAttribute('aria-label')?.startsWith('Play ')) set(el, 'tuiNavControl', 'true');
      });
    }
    set(document.querySelector('#Desktop_LeftSidebar_Id'), 'tuiPane', ' LIB ');
    const path = window.Spicetify?.Platform?.History?.location?.pathname || '';
    const pageName = path === '/' ? 'HOME' : path.startsWith('/search') ? 'SEARCH' : path.startsWith('/artist') ? 'ARTIST' : path.startsWith('/collection') ? 'LIBRARY' : path.startsWith('/marketplace') ? 'EXTENSIONS' : 'TRACKS';
    set(document.querySelector('#main-view'), 'tuiPane', ` ${pageName} `);
    set(document.querySelector('#main-view'), 'tuiPage', pageName.toLowerCase());
    set(document.querySelector('[aria-label="Home Filters"]')?.closest('.contentSpacing')?.parentElement, 'tuiHomeFilters', 'true');
    document.querySelectorAll('#main-view [data-testid="shortcut-background"]').forEach(el => set(el.parentElement.parentElement, 'tuiHomeShortcut', 'true'));
    const right = document.querySelector('.Root__top-container > div:has(aside.NowPlayingView)');
    set(right, 'tuiPane', 'INSPECT');
    document.querySelectorAll('[data-tui-pane="INSPECT"] h2').forEach(el => {
      const section = el.parentElement.parentElement;
      if (el.textContent.trim() === 'About the artist') {
        set(section.parentElement, 'tuiArtistArt', 'true');
      } else set(section, 'tuiSection', el.textContent.trim());
    });
    set(document.querySelector('[data-testid="track-visual-enhancement"]')?.parentElement, 'tuiArtShell', 'true');
    set(document.querySelector('.main-nowPlayingBar-container'), 'tuiPane', ' TRANSPORT ');
    const volume = document.querySelector('[data-testid="volume-bar"]');
    const nextInput = volume?.querySelector('input[type="range"]');
    if (nextInput && volumeInput !== nextInput) {
      volumeInput?.removeEventListener('input', updateVolume);
      volumeInput = nextInput;
      volumeInput.addEventListener('input', updateVolume);
    }
    if (volume && !volume.querySelector('[data-tui-volume-readout]')) {
      volumeLabel = document.createElement('span');
      volumeLabel.dataset.tuiVolumeReadout = 'true';
      volumeLabel.setAttribute('aria-hidden', 'true');
      volume.append(volumeLabel);
      lastVolume = '';
    } else volumeLabel = volume?.querySelector('[data-tui-volume-readout]');
    updateVolume();
    document.querySelectorAll('#Desktop_LeftSidebar_Id [role="row"][aria-selected]').forEach(el => {
      set(el, 'tuiIndex', String(el.getAttribute('aria-rowindex')).padStart(2, '0'));
      const title = el.querySelector('[data-encore-id="listRowTitle"]')?.textContent.trim();
      if (title) set(el, 'tuiShort', title === 'Liked Songs' ? 'LIKE' : [...title].slice(0, 4).join(''));
    });
    const pane = document.querySelector('#main-view');
    const header = pane?.querySelector('[data-testid="entity-header"]');
    set(pane, 'tuiStuck', String(!header || header.getBoundingClientRect().bottom < pane.getBoundingClientRect().top + 72));
    for (const [selector, label] of [
      ['.Root__globalNav button[aria-label="Go back"]', '[<]'],
      ['.Root__globalNav button[aria-label="Go forward"]', '[>]'],
      ['.Root__globalNav button[aria-label="Home"]', '[HOME]'],
      ['.Root__globalNav button[aria-label="Marketplace"]', '[EXT]'],
      ['[data-testid="control-button-skip-back"]', '|<'],
      ['[data-testid="control-button-skip-forward"]', '>|'],
      ['[data-testid="control-button-playpause"]', document.querySelector('[data-testid="control-button-playpause"]')?.getAttribute('aria-label') === 'Pause' ? '||' : '>'],
    ]) set(document.querySelector(selector), 'tuiLabel', label);
  }
  const observer = new MutationObserver(() => {
    if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; decorate(); }); }
  });
  observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['aria-label', 'aria-selected', 'aria-rowindex'] });
  const onScroll = () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; decorate(); }); } };
  document.addEventListener('scroll', onScroll, true);
  decorate();
  const volumeTimer = setInterval(updateVolume, 250);
  window.__terminalThemeCleanup = () => {
    clearTimeout(chromeRetry);
    restoreWindowChrome?.();
    observer.disconnect();
    document.removeEventListener('scroll', onScroll, true);
    volumeInput?.removeEventListener('input', updateVolume);
    clearInterval(volumeTimer);
  };
})();

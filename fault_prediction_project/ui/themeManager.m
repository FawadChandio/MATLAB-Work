function applyTheme(theme)
    switch theme
        case 'dark'
            set(gcf, 'Color', [0.1 0.1 0.1]);
        case 'light'
            set(gcf, 'Color', [1 1 1]);
    end
end
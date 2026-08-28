return {
    -- ys / cs / ds. Unmaintained but finished: ~600 lines of Vimscript against
    -- APIs frozen since Vim 7. Successor if it ever breaks: mini.surround
    -- (note: different keys -- gsa/gsd/gsr).
    { "tpope/vim-surround", event = "VeryLazy" },

    { "m4xshen/autoclose.nvim", event = "InsertEnter", config = true },
}

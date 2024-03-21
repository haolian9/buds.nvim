an example to auto add list item


## design
* keep the logic minimal
* only supports i_cr

## known wontfix issues
* not work with: p, o, O
* not support multi-line list item
* `<cr><cr>` will remove the trailing space from the previous line,
  which is caused by &autoindent, actually i'd treat it as a feature
* `<cr><cr>` will not remove the previously inserted `*` line

## status
* just works
* may conflict with other plugins

## prerequisites
* nvim 0.9.*
* haolian9/infra.nvim

## usage
* `:lua require'buds'.attach(vim.api.nvim_get_current_bufnr())`

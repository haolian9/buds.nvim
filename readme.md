an example to auto add list item

https://github.com/haolian9/zongzi/assets/6236829/455472be-e3eb-43dc-9183-ee1cee0de083

## design
* keep the logic minimal
* only supports i_cr

## known wontfix issues
* not work with: p, o, O, gw, gq
* not support multi-line list item
* `<cr><cr>` will remove the trailing space from the previous line,
  which is caused by &autoindent, actually i'd treat it as a feature
* `<cr><cr>` will not remove the previously inserted `*` line

## status
* it works imperfectly, and may malfunction in unaware edge cases
* edge cases keep making the logic complex more and more, which frustrates me
* may conflict with other plugins

## prerequisites
* nvim 0.9.*
* haolian9/infra.nvim

## usage
* `:lua require'buds'.attach(vim.api.nvim_get_current_bufnr())`

my personal config:
```
do -- requires haolian9/cmds.nvim
  local spell = cmds.Spell("Buds", function(args)
    local buds = require("buds")
    local bufnr = api.nvim_get_current_buf()
    if args.op == "attach" then
      buds.attach(bufnr)
    elseif args.op == "detach" then
      buds.detach(bufnr)
    else
      error("unreachable")
    end
  end)
  spell:add_arg("op", "string", true, nil, cmds.ArgComp.constant({ "attach", "detach" }))
  cmds.cast(spell)
end
```

---

新年都未有芳华，二月初惊见草芽。  
白雪却嫌春色晚，故穿庭树作飞花。  


红豆生南国，春来发几枝。  
愿君多采撷，此物最相思。  

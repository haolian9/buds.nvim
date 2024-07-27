an example to auto add list item

https://github.com/haolian9/zongzi/assets/6236829/455472be-e3eb-43dc-9183-ee1cee0de083

## design
* trigger intentionally
* no nvim_buf_attach, which leads to an unstable fragile impl
* not support multi-line list item

## status
* just works
* yet may conflict with other plugins

## prerequisites
* nvim 0.10.*
* haolian9/infra.nvim

## usage

my personal config:
```
bm.i("<s-cr>", function() require("buds")() end)
```

## about the name

新年都未有芳华，二月初惊见草芽。  
白雪却嫌春色晚，故穿庭树作飞花。  


红豆生南国，春来发几枝。  
愿君多采撷，此物最相思。  

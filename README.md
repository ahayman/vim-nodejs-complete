vim-nodejs-complete
===================

Nodejs `'omnifunc'` function of vim

Support node's builtin module's method&property completion(`ctrl-x ctrl-o`) in `js` file with preview.


## Install
Download the [tarball](https://github.com/ahayman/vim-nodejs-complete/zipball/master) and extract to your vimfiles(`~/.vim` or `~/vimfiles`) folder.

Completion require `:filetype plugin on`, please make sure it's on.

## Settings
All the settings is optional.

```viml
let g:nodejs_complete_config = {
\  'js_compl_fn': 'jscomplete#CompleteJS',
\  'max_node_compl_len': 15
\}
```

### js_compl_fn
* `String` function name, called to complete javascript
* default to `javascriptcomplete#CompleteJS`
* if you want to integrate with [jscomplete](https://github.com/teramako/jscomplete-vim), set it to `jscomplete#CompleteJS`, make sure it's installed.

### max_node_compl_len
* `Number`, length of nodejs complete items. set to 0 if unlimited


## Example

```js
var fs = req
// then hit ctrl-x_ctrl-o you'll get:
var fs = require(
// and then hit ctrl-x_ctrl-o again you'll get module name completion

var fs = require('f
// then hit ctrl-x_ctrl-o

fs.
// then hit ctrl-x_ctrl-o

proc
// then hit ctrl-x_ctrl-o

process.ex
// then hit ctrl-x_ctrl-o
```

## Local Modules (beta)

* Node_complete will now search through the 'node_modules' directy and all subdirectories of 'node_modules' to extract the completion information for local modules.
* It will search through each .js file it finds for node 'exports' it can use for completion. 
* It will also parse the package.json file to discover the module name and use 'main' (if available) to match it with the appropriate .js file. If the package.json doesn't have a 'main' entry, node_complete will attempt to match it with a .js file in the same directory with the same name as the module. If there is no .js file with the same name as the module, it will match the package.json file with whatever .js file it can find.  If there is more than one .js file in the directory, the package.json will be matched to one of them, but which one it matches to will be undefined.  If it can't find a package.json file, it will use the name of the .js file for the module name.  
* Please note: it will cut short it's json processing when it discovers the module name and main OR if it comes across a 'readme' entry.  This is to prevent it from processing a lot of unnecessary data, like extra long readme's that some dev's are fond of.  If, for some strange reason, someone has placed a readme before the module 'name' or 'main' entry, it will fail to find those entry(s). I do this because vimscript isn't great at iterating over long strings and long readme's can significantly slow down the processing. If you're experiencing long processing time, try to move the 'main' and 'name' entries to the top of the json.package file.  That should help. 
* It will process local node data when you first open the file/buffer. Local node data is only kept around while the buffer exists.  If you close the buffer, the local node data is discarded.  This means you can refresh your auto-completion by reopening a file.
* You can also refresh your local node completeion data by entering ":ReloadNodeComplete" or it's shortcut ":RNC". Node_complete will then discard the local data and reprocess all nodes as described above.  This can be very usefull if you've modified a local node and want completion data for the changes.

## Tip
1. Close the method preview window

     `ctrl-w_ctrl-z` or `:pc`.

     If you want close it automatically, put the code(from [spf13-vim](https://github.com/spf13/spf13-vim/blob/3.0/.vimrc)) below in your `.vimrc` file.

     ```vim
     " automatically open and close the popup menu / preview window
     au CursorMovedI,InsertLeave * if pumvisible() == 0|silent! pclose|endif
     ```

2. About vim's complete

     Vim supports several kinds of completion, `:h ins-completion` for help.

3. Completion of module in `node_modules` will cache result of every `js` file

     If you modified module in `node_modules` directory, use code below to clear the cache.

     ```vim
     :unlet b:npm_module_names
     ```


## Feedback
[feedback or advice or feature-request](https://github.com/myhere/vim-nodejs-complete/issues)


if exists('&ofu')
    setlocal omnifunc=nodejscomplete#CompleteJS
endif

let b:node_local = {}
let b:node_local_json = {}
let b:node_local_unmatched = []

function! s:fuzglob(expr)"{{{
      " Substitutes "\", because on Windows, "**\" doesn't include ".\",
      "   " but "**/" include "./". I don't know why.
   return split(glob(substitute(a:expr, '\', '/', 'g')), "\n")
endfunction"}}}
           
 
function! s:indexOfEnclosingDoubleQuote(string, index)"{{{
    let i = a:index
    while 1
        let match = match(a:string, '"', i)
        if (match < -1)
            break
        endif

        let i = match

        if (strpart(a:string, match - 1, 1) != '\\')
            break
        endif
    endwhile
    return i
endfunction"}}}

function! s:objectFromJson(jsonString)"{{{
    let len = strlen(a:jsonString)
    let json = {}
    if (len > 0)
        let len -= 1
    else
        return json
    endif
    let i = match(a:jsonString, '{') + 1
    let context = {'name': 'root', 'isDict': 1, 'data': json}
    let path = []
    let keyBuffer = ''
    let valueBuffer = ''
    let valFilling = 0
    let nextBufIsVal = 0
    let foundName = 0
    let foundMain = 0
    while i < len
        let c = strpart(a:jsonString, i, 1) 
        let i += 1
        if (c == '{')
            let newContext = {'isDict' : 1, 'data' : {}}
            if (strlen(keyBuffer) && context.isDict)
                let context.data[keyBuffer] = newContext.data
            elseif (!context.isDict && nextBufIsVal)
                call add(context.data, newContext.data)
            else
                silent! echo 'new dictionary was found, but no key is in the buffer and the current object is a dict. Index: ' . i
            endif
            call add(path, context)
            let context = newContext
            let nextBufIsVal = 0
            let keyBuffer = ''
            let valueBuffer = ''
        elseif (c == '[')
            let newContext = {'isDict' : 0, 'data' : []}
            if (context.isDict)
                if (strlen(keyBuffer))
                    let context.data[keyBuffer] = newContext.data
                endif
            else 
                call add(context.data, newContext.data)
            endif
            call add(path, context)
            let context = newContext
            let nextBufIsVal = 1
            let keyBuffer = ''
            let valueBuffer = ''
        elseif (c == '}' || c == ']')
            " Append the buffer (if any) to the correct object
            if (context.isDict)
                if (strlen(keyBuffer))
                    let context.data[keyBuffer] = valueBuffer
                    if (keyBuffer == 'name' && context.data == json)
                        let foundName = 1
                    endif
                    if (keyBuffer == 'main' && context.data == json)
                        let foundMain = 1
                    endif
                endif
            else
                if (strlen(valueBuffer))
                    call add(context.data, valueBuffer)
                endif
            endif
            
            " Pop the last element and use as current
            if (len(path) > 0)
                let context = remove(path, len(path) - 1)
            endif
            
            if (context.isDict)
                let nextBufIsVal = 0
            else
                let nextBufIsVal = 1
            endif

            let valFilling = 0
            let valueBuffer = ''
            let keyBuffer = ''
        elseif (c == ' ')
            continue
        elseif (c == '"')
            if (valFilling)
                let valFilling = 0
            elseif (context.isDict)
                if (nextBufIsVal)
                    let closingIndex = s:indexOfEnclosingDoubleQuote(a:jsonString, i)
                    let valueBuffer = strpart(a:jsonString, i, closingIndex - i)
                    let i = closingIndex + 1
                    let valFilling = 0
                else
                    let closingIndex = s:indexOfEnclosingDoubleQuote(a:jsonString, i)
                    let keyBuffer = strpart(a:jsonString, i, closingIndex - i)
                    let i = closingIndex + 1
                    let valFilling = 0
                endif
            else
                let closingIndex = s:indexOfEnclosingDoubleQuote(a:jsonString, i)
                let valueBuffer = strpart(a:jsonString, i, closingIndex - i)
                let i = closingIndex + 1
                let valFilling = 0
            endif
        elseif (c == ':' && context.isDict == 1)
            " We're shortcutting the process because readme's can be very long
            if (keyBuffer ==? 'readme')
                return json
            endif
            let nextBufIsVal = 1
        elseif (c == ',')
            if (context.isDict)
                if (strlen(keyBuffer))
                    let context.data[keyBuffer] = valueBuffer
                    if (keyBuffer == 'name' && context.data == json)
                        let foundName = 1
                    endif
                    if (keyBuffer == 'main' && context.data == json)
                        let foundMain = 1
                    endif
                endif
                let nextBufIsVal = 0
            else
                if (strlen(valueBuffer))
                    call add(context.data, valueBuffer)
                endif
                let nextBufIsVal = 1
            endif
            let valueBuffer = ''
            let keyBuffer = ''
            let valFilling = 0
        else
            if (valFilling)
                let valueBuffer = valueBuffer . c
            else
                let valFilling = 1
                let valueBuffer = valueBuffer . c
            endif
        endif
        if (foundName && foundMain)
            return json
        endif
   endwhile
   return json
endfunction"}}}

function! s:moduleMainFromPackageJson(jsonPath)"{{{
   if (!has_key(b:node_local_json, a:jsonPath))
       let lines = readfile(a:jsonPath)
       let string = ''
       for line in lines
           let string = string . line
       endfor
       let json = s:objectFromJson(string)
       let b:node_local_json[a:jsonPath] = json
   else
       let json = b:node_local_json[a:jsonPath]
   endif
   let main = ''
   if (has_key(json, 'main'))
       let main = json.main
   else
       let directory = strpart(a:jsonPath, 0, match(a:jsonPath, '[^/\\]\+$'))
       if (filereadable(directory . json.name . '.js'))
           silent! echo 'filereadable: ' . directory . json.name . '.js'
           let main = json.name . '.js'
       else
           let package = {'path': directory, 'json': json}
           silent! echo string(package)
           call add(b:node_local_unmatched, package)
       endif
   endif

   return main

endfunction"}}}

function! s:moduleNameFromPackageJson(jsonPath)"{{{
   if (!has_key(b:node_local_json, a:jsonPath))
       let lines = readfile(a:jsonPath)
       let string = ''
       for line in lines
           let string = string . line
       endfor
       let json = s:objectFromJson(string)
       let b:node_local_json[a:jsonPath] = json
   else
       let json = b:node_load_json[a:jsonPath]
   endif
   let name = ''
   if (has_key(json, 'name'))
       let name = json.name
   endif

   return name
            
endfunction"}}}

function! s:moduleNameAtPath(path)"{{{
  let directory = strpart(a:path, 0, match(a:path,'[^/\\]\+$')) 
  let i = 0
  let name = ''
  for package in b:node_local_unmatched
      if (directory == package.path)
          call remove(b:node_local_unmatched, i)
          return package.json.name
      endif
      let i += 1
  endfor

  let index = match(a:path, 'node_modules')
  if (index > -1)
      let name = strpart(a:path, index)
  endif

  if (strlen(name) < 1)
      let name =  matchstr(directory, '[^/\\]\+$')
  endif
          
return name
endfunction"}}}

function! s:extractModulesPaths(paths)"{{{

    let modules = []
    " Process package.json files first
    let jPaths = copy(a:paths)
    for path in jPaths
        if (path =~? 'package\.json')
            call remove(a:paths, index(a:paths, path))
            let moduleName = s:moduleNameFromPackageJson(path)
            let main = s:moduleMainFromPackageJson(path)
            if (strlen(main))
                let module = {}
                let module.name = moduleName
                let pathDir = strpart(path, 0, match(path, '[^/\\]\+$'))
                let mainDir = strpart(main, 0, match(main, '[^/\\]\+$'))
                let mainPath = simplify(pathDir . main)
                if (match(mainPath, '\.js') < 0)
                    let tryFile = simplify(mainPath . '.js')
                    if (filereadable(tryFile))
                        let mainPath = tryFile
                    elseif (isdirectory(mainPath))
                        let mainPath = simplify(mainPath . '/index.js')
                    endif
                endif
                let module.data = s:extractModuleDataAtPath(mainPath)
                for spath in a:paths
                    if (spath =~ main)
                        call remove(a:paths, index(a:paths, spath))
                        break
                    endif
                endfor
                let main = matchstr(main, '[^/\\]\+$')
                if (main =~? '\.js')
                    let main = strpart(main, match(main, 'node_modules'))
                endif
                let module.main = main
                call add(modules, module)
            endif
        endif
    endfor
    
    for path in a:paths
        let moduleName = s:moduleNameAtPath(path)
        if (strlen(moduleName) > 0)
            let module = {}
            let module.name = moduleName
            let module.data = s:extractModuleDataAtPath(path)
            call add(modules, module)
        endif
    endfor

    let b:node_local.modules = modules 

endfunction"}}}

function! s:extractModuleDataAtPath(module_path)"{{{
    let matched = []
    if (!filereadable(a:module_path))
        return matched
    endif
    let fileLines = readfile(a:module_path)
    for line in fileLines
        let index = match(line, 'exports\.')
        if (index > -1 && match(line, '=') > index)
            let line = strpart(line, matchend(line, 'exports\.'))
            let nameIndex = match(line, ' ')
            let name = strpart(line, 0, nameIndex)
            let functionIndex = match(line, 'function(')
            let info = ''
            if (functionIndex > 0)
                let endFunctionIndex = match(line, ')')
                if (endFunctionIndex > functionIndex)
                    let info = strpart(line, functionIndex + 8, endFunctionIndex - functionIndex - 7)
                endif
            else
                for cline in fileLines
                    if (cline =~ name && cline =~ 'function')
                        let functionIndex = match(cline, '(')
                        let endFunctionIndex = match(cline, ')')
                        if (endFunctionIndex > functionIndex)
                            let info = strpart(cline, functionIndex, endFunctionIndex - functionIndex + 1)
                            break
                        endif
                    endif
                endfor
            endif
            if (strlen(info) > 0)
                let match = {'word' : name, 'info' : name . info, 'kind' : 'f'}
            else
                let match = {'word' : name, 'info' : ' ', 'kind' : 'm'}
            endif
            call add(matched, match)
        endif
    endfor
    return matched
endfunction"}}}

function! s:getModulePathsInFolder(current_dir, recursive)"{{{

  let ret = []

  let files = s:fuzglob(a:current_dir . '/*')
  for file in files
    if (isdirectory(file) && a:recursive)
      let subFiles = s:getModulePathsInFolder(file, 0)
      if len(subFiles)
          let ret = extend(ret, subFiles)
      endif
    elseif (!isdirectory(file) && file =~? '\.js$')
      let ret = add(ret, file)
    elseif (!isdirectory(file) && file =~? 'package\.json')
        let ret = add(ret, file)
    endif
  endfor
  return ret
endfunction"}}}

function! s:compileLocalNodeData()"{{{
    let modules_dir = expand('%:p:h') . '/node_modules'

    if (isdirectory(modules_dir))
       call s:extractModulesPaths(s:getModulePathsInFolder(modules_dir, 1)) 
    endif
    let b:node_local_json = {}
    let b:node_local_unmatched = []
endfunction"}}}

function! ReloadNodeComplete()"{{{
    call s:compileLocalNodeData()
    if (has_key(b:node_local, "modules"))
        silent! echo "nodejsComplete: Reloaded '" . len(b:node_local.modules) . "' local nodes"
    else
        silent! echo "nodejsComplete: Found no local nodes to reload"
    endif
        
endfunction"}}}

command! -nargs=0 ReloadNodeComplete call ReloadNodeComplete()
command! -nargs=0 RNC call ReloadNodeComplete()

if exists('&ofu')
    call s:compileLocalNodeData()
    if (has_key(b:node_local, "modules"))
        silent! echo "nodejsComplete: Loaded '" . len(b:node_local.modules) . "' local nodes"
    else
        silent! echo "nodejsComplete: Found no local nodes to load"
    endif
endif

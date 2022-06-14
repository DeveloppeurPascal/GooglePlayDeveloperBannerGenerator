# Project file description

File extension : GPBG

File format :

* header : "GPBG" (4 bytes - ASCII value)
* version number : 1 (byte)
* global datas block
* images list block

## Block "Global datas"

* Version number : 1 (byte)

## Block "Images list"

* Version number : 1 (byte)
* Nb images : x (word)
* x images blocks

## Block "Image"

* Version number : 1 (byte)
* Buffer size : x (cardinal)
* Image buffer : (x bytes)

format PE console
entry start
include 'win32a.inc'

section '.text' code executable readable

TAPE_SIZE = 3000

start:
	; Get handle to standard output
	invoke	GetStdHandle, STD_OUTPUT_HANDLE
	mov	[hStdout], eax
	invoke	GetStdHandle, STD_INPUT_HANDLE
	mov	[hStdin], eax

	invoke	GetProcessHeap
	mov	[hHeap], eax

	stdcall GetArgumentCount
	cmp	eax, 1
	jne	load_file

	invoke	WriteConsoleA, [hStdout], _usage, msg_size, charsWritten, 0
	jmp	end_prog


      load_file:

	stdcall GetArgument, 1

	; read the data
	invoke	CreateFileA, eax, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
	mov	[hFile], eax
	invoke	GetFileSize, eax, NULL
	mov	[file_size], eax

	inc	eax
	invoke	HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, eax
	mov	[code_ptr], eax

	invoke	ReadFile, [hFile], eax, [file_size], NULL, NULL

	call	interpret

	; Exit program
      end_prog:
	invoke	ExitProcess, 0

      bracket_error:
	invoke	MessageBox, 0, _brack_err, _brack_err, 0
	jmp	end_prog

interpret:
	; loop on every char until \0
	invoke	HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, TAPE_SIZE
	mov	[hTape], eax
	mov	DWORD [tape_ptr], 0
	mov	esi, [code_ptr]
	mov	eax, 0

      @@:
	lodsb
	cmp	al, 0
	je	@f
	cmp	al, '>'
	je	mov_right
	cmp	al, '<'
	je	mov_left
	cmp	al, '+'
	je	increment
	cmp	al, '-'
	je	decrement
	cmp	al, '.'
	je	output
	cmp	al, ','
	je	replace
	cmp	al, '['
	je	jmp_forward
	cmp	al, ']'
	je	jmp_backward
	jmp @b
      mov_right:
	inc	DWORD [tape_ptr]
	jmp	@b
      mov_left:
	dec	DWORD [tape_ptr]
	jmp	@b
      increment:
	mov	eax, [hTape]
	add	eax, [tape_ptr]
	inc	BYTE [eax]
	jmp	@b
      decrement:
	mov	eax, [hTape]
	add	eax, [tape_ptr]
	dec	BYTE [eax]
	jmp	@b
      output:
	mov	eax, [hTape]
	add	eax, [tape_ptr]
	invoke	WriteConsoleA, [hStdout], eax, 1, charsWritten, 0
	jmp	@b
      replace:
	mov	ebx, [hTape]
	add	ebx, [tape_ptr]
	invoke	ReadFile, [hStdin], ebx, 1, NULL, NULL
	jmp	@b
      jmp_forward:
	mov	eax, [hTape]
	add	eax, [tape_ptr]
	cmp	BYTE [eax], 0
	jne	@b

	call	jmp_to_next_bracket
	jmp	@b
      jmp_backward:
	mov	eax, [hTape]
	add	eax, [tape_ptr]
	cmp	BYTE [eax], 0
	je     @b

	call	jmp_to_previous_bracket
	jmp	@b
      @@:

	ret


jmp_to_next_bracket:
	mov	ebx, 0	; holds the number of nested brackets encountered

      @@:
	lodsb
	cmp	al, 0
	je	bracket_error
	cmp	al, '['
	je	.nested_bracket
	cmp	al, ']'
	je	.unnest_bracket
	jmp	@b
      .nested_bracket:
	inc	ebx
	jmp	@b
      .unnest_bracket:
	cmp	ebx, 0
	je	@f
	dec	ebx
	jmp	@b
      @@:

	ret


jmp_to_previous_bracket:
	sub	esi, 2	; esi already passed the bracket and now points
			; to the char after, but we want it to point to
			; the char before
	mov	ebx, 0	; holds the number of nested brackets encountered

      @@:
	mov	al, BYTE [esi]
	dec	esi
	cmp	al, 0
	je	bracket_error
	cmp	al, ']'
	je	.nested_bracket
	cmp	al, '['
	je	.unnest_bracket
	jmp	@b
      .nested_bracket:
	inc	ebx
	jmp	@b
      .unnest_bracket:
	cmp	ebx, 0
	je	@f
	dec	ebx
	jmp	@b
      @@:

	inc	esi
	ret

include 'commandline.inc'

section '.data' data readable writeable

	charsWritten dd 0
	_brack_err db 'No matching brackets', 0
	_usage db 'Quick and dirty brainfuck interpreter, by JGN1722 (Github)', 10, 13
	       db 'Usage: brainfuck [filename]', 10, 13, 0
	msg_size = $ - _usage

	hStdout dd 0
	hStdin dd 0

	hHeap dd 0

	hFile dd 0
	file_size dd 0

	code_ptr dd 0

	hTape dd 0
	tape_ptr dd 0

section '.idata' import data readable writeable
	; standard DLL imports
	library kernel32, 'KERNEL32.DLL',\
		user32, 'USER32.DLL',\
		gdi32, 'GDI32.DLL',\
		comctl32, 'COMCTL32.DLL'
	include 'api\kernel32.inc'
	include 'api\user32.inc'
	include 'api\gdi32.inc'
	include 'api\comctl32.inc'

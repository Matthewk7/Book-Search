; Author: Matthew Kale
; Section: 1003
; Date Last Modified: 10/26/20
; Program Description: Progam to demonstare mastery of File I/O and Circular Buffers


section .data 
	; System Service Call Constants
	STANDARD_IN     equ 0
	STANDARD_OUT    equ 1
	SYSTEM_READ     equ 0
	SYSTEM_WRITE    equ 1
    SYSTEM_OPEN     equ 2
    SYSTEM_CLOSE    equ 3
    SYSTEM_CREATE   equ 85
    SYSTEM_EXIT     equ 60
    EXIT_SUCCESS    equ 0
    EXIT_FAILURE    equ 0
    TRUE            equ 1
    FALSE           equ 0

	; ASCII Values
	NULL        equ 0
	LINEFEED    equ 10

    O_RDONLY    equ 000000q        ; Read only
    O_WRONLY    equ 000001q        ; Write only
    O_RDWR      equ 000002q        ; Read and write

    S_IRUSR     equ 00400q          ; Owner, read permission
    S_IWUSR     equ 00200q          ; Owner, write permission
    S_IXUSR     equ 00100q          ; Owner, execute permission




    ; Error Messages
    errorThreeArguments db "Enter <File Name> and string to search for after the program name.", LINEFEED, NULL
    errorFileReadOpenFailure db "Error Read File Open Failure", LINEFEED, NULL
    errorFileWriteOpenFailure db "Error Write File Open Failure", LINEFEED, NULL
    errorStringTooLong db "Error String Must Be 20 Characters Or Less", LINEFEED, NULL
    errorBufferingCharacters db "Error Buffering The Characters", LINEFEED, NULL
    noMatchingEntries db "No matching entries found in file.", NULL

    ; Variables for main
    outputFileName db "results.txt", NULL
    MAXIMUM_INPUT_SIZE equ 20
    BUFFER_SIZE equ 1
    printOut db "Line: 0x00000000 Column: 0x00000000", LINEFEED, NULL
    inputFileDescriptor dq 0
    outputFileDescriptor dq 0
    charactersBuffered dd 0
    charactersRead dd 0
    endOfFileReached dd 0
    circularIndexRead dd 0
    circularIndexWrite dd 0
    columnNumber dd 0
    rowNumber dd 1
    resultsFileIsEmpty dd 1

section .bss
    readBuffer resb BUFFER_SIZE
    circularBuffer resb MAXIMUM_INPUT_SIZE
    circularBufferSize resb 1       ; Will match size of input

section .text
global main
main:

    mov r12, rdi    ; Argc
    mov r13, rsi    ; Argv

    ; Ensure there are 3 command line arguments 
    cmp r12, 3
    je getCircularBufferSize
        mov rdi, errorThreeArguments
        call endOnError

    ; Get circular buffer size
    getCircularBufferSize:
        mov rdi, qword[r13 + 16]
        call stringLength
        dec rax
        mov byte[circularBufferSize], al

    ; Ensure length isn't too long
    cmp al, MAXIMUM_INPUT_SIZE
    jle openInputFile

    ; End program if the length is too long
    mov rdi, errorStringTooLong
    call endOnError

    openInputFile:
        mov rax, SYSTEM_OPEN
        mov rdi, qword[r13 + 8]
        mov rsi, O_RDONLY
        syscall

    ; Ensure the file opened successfully 
    cmp rax, 0
    jge fileReadOpenSuccess

    ; End if file didn't open successfully
    mov rdi, errorFileReadOpenFailure
    call endOnError


    fileReadOpenSuccess:
        mov qword[inputFileDescriptor], rax


    openOutputFile:
        mov rax, SYSTEM_CREATE
        mov rdi, outputFileName
        mov rsi, S_IRUSR | S_IWUSR
        syscall

    ; Ensure the output file opened
    cmp rax, 0 
    jge fileWriteOpenSuccess

    ; End if the file didn't open correctly
    mov rdi, errorFileWriteOpenFailure
    call endOnError

    fileWriteOpenSuccess:
    mov qword [outputFileDescriptor], rax
    mov r15, qword[r13 + 16]

    ; Get the length of the circular buffer to loop
    loopFillCircularBufferSetup:
        mov rdi, r15
        call stringLength
        mov rcx,rax
        dec rcx

    loopFillCircularBuffer:
        push rcx

        ; Get a character to fill the circular buffer
        mov rdi, circularBuffer
        call getBufferedCharacter

        ; See if the character grab returned an error
        mov rbx, -1
        cmp rax, rbx
        jne allCharactersBufferedCheck

        ; End program if the character grab returned an error
        mov rdi, errorBufferingCharacters
        call endOnError


        allCharactersBufferedCheck:
            mov rbx, 0
            cmp rax, rbx
            jne notAllBuffered
            ; Set r14 to true if there are no more available characters
            mov r14, TRUE
        notAllBuffered:
        pop rcx
    loop loopFillCircularBuffer

    ; Set the characters read back to the start of next string
    movsxd rax, dword[charactersRead]
    movsxd rbx, dword[circularBufferSize]
    sub rax, rbx
    inc rax
    mov dword[charactersRead], eax

    ; Set the start of the circular index to the next character
    movsxd rax, dword[circularIndexRead]
    inc rax
    mov dword[circularIndexRead], eax
    
    ; Compare the string to the string in circular buffer
    mov rdi, r15
    mov rsi, circularBuffer
    call compareStringToBuffer

    ; Check if we are done searching
    mov rbx, 1
    cmp r14, rbx
    je searchingComplete
    jmp loopFillCircularBufferSetup

    searchingComplete:

    ; See if file is empty
    movsxd rbx, dword[resultsFileIsEmpty]
    cmp rbx, TRUE
    jne closeInputFile
    
    ; Print out to the file if it is empty
    mov rdi, noMatchingEntries
    call stringLength
    mov rdx, rax
    dec rdx
    mov rax, SYSTEM_WRITE
    mov rdi, qword[outputFileDescriptor]
    mov rsi, noMatchingEntries
    syscall


    ; Close input file
    closeInputFile:
        mov rax, SYSTEM_CLOSE
        mov rdi, qword[inputFileDescriptor]
        syscall

    ; Close output file
    mov rax, SYSTEM_CLOSE
    mov rdi, qword[outputFileDescriptor]
    syscall

endProgram:
    mov rax, SYSTEM_EXIT
    mov rdi, EXIT_SUCCESS
    syscall


;	Counts the number of characters in the null terminated string
;	rdi - string address
;	rax - return # of characters in string (including null)
global stringLength
stringLength:
	mov rax, 1
	
	countCharacterLoop:
		mov cl, byte[rdi + rax - 1]
		cmp cl, NULL
		je countCharacterDone
		
		inc rax
	jmp countCharacterLoop
	countCharacterDone:
ret


;	Prints the provided null terminated string
;	rdi - string address
global printString
printString:
	push rdi
	call stringLength
	pop rdi
	
	mov rdx, rax	; string length
	mov rax, SYSTEM_WRITE
	mov rsi, rdi
	mov rdi, STANDARD_OUT
	syscall
ret

;	Prints an error message and ends the program
;	rdi - string address of error message
global endOnError
endOnError:
	call printString

	mov rax, SYSTEM_EXIT
	mov rdi, EXIT_FAILURE
	syscall
ret

;	Convert integer to hexadecimal string
;	rdi: dword integer variable by reference
;	rsi: string (11 byte array) by reference
global convertIntegerToHexadecimal
convertIntegerToHexadecimal:
	push rbx

	mov byte[rsi], "0"
	mov byte[rsi+1], "x"
	
	mov rbx, rsi
	add rbx, 9
	
	mov r8d, 16 ;base
	mov rcx, 8
	mov eax, dword[rdi]
	convertHexLoop:
		mov edx, 0
		div r8d
		
		cmp dl, 10
		jae addA
			add dl, "0" ; Convert 0-9 to "0"-"9"
		jmp nextDigit
		
		addA:
			add dl, 55 ; 65 - 10 = 55 to convert 10 to "A"
			
		nextDigit:
			mov byte[rbx], dl
			dec rbx
			dec rcx
	cmp eax, 0
	jne convertHexLoop

	addZeroes:
		cmp rcx, 0
		je endHexConversion
		mov byte[rbx], "0"
		dec rbx
		dec rcx
	jmp addZeroes
	endHexConversion:

	pop rbx
ret

; Store a character from buffer
; Argument 1 (rdi) - Address to store character
; Return (rax) - 1 if successful
;                0 if no more characters are available
;                -1 if there was an error
global getBufferedCharacter
getBufferedCharacter:
    push rbp
    push rdi

    ; Get the next character in the buffer
    getNextCharacter:

    ; Check if we have gotten all the buffered characters
    movsxd r9, dword[charactersRead]
    movsxd r10, dword[charactersBuffered]
    movsxd r11, dword[circularIndexRead]
    cmp r9, r10
    jge readNotSuccessful
    
    ; Move the next buffered character into circular buffer
    pop rdi
    mov al, byte[readBuffer + r9]
    mov byte[rdi + r11], al
    inc r9 
    inc r11
    mov rax, r11
    movsxd rbx, dword[circularBufferSize]
    mov rdx, 0
    div rbx
    mov r11, rdx

    ; Move 1 to return success
    mov rax, 1
    jmp endStoreBufferedCharacter

    readNotSuccessful:
        ; See if the end of the file was reached
        cmp dword[endOfFileReached], TRUE
        jne notEndOfFile

        ; Move 0 to return no more available characters 
        mov rax, 0
        pop rdi
        jmp endStoreBufferedCharacter

        notEndOfFile:
            ; Fill large buffer if it is not end of file
            mov rax, SYSTEM_READ
            mov rdi, qword[inputFileDescriptor]
            mov rsi, readBuffer
            mov rdx, BUFFER_SIZE
            syscall
            
            ; See if reading it was a success
            cmp rax, 0
            jge fileReadSuccess

            ; Move 1 to return read failure if there was an error
            mov rax, -1
            jmp endStoreBufferedCharacter
    
            fileReadSuccess:
                ; See if the end of the file was reached
                cmp eax, BUFFER_SIZE
                je bufferIsFull
                mov dword[endOfFileReached], TRUE
            

            bufferIsFull:
                ; Set the characters read back to 0
                mov dword[charactersRead], 0
                ; Reset the number of characters in buffer
                mov dword[charactersBuffered], eax

            jmp getNextCharacter
    endStoreBufferedCharacter:
        ; Update characters read and circular index
        mov dword[charactersRead], r9d
        mov dword[circularIndexRead], r11d
        pop rbp
ret 

; Compare the string to the string in the buffer
; Argument 1 (rdi) - Address to store the string
; Argument 2 (rsi) - Address of the circular buffer
global compareStringToBuffer
compareStringToBuffer:
    
    ; Get a character from the string
    ; Get a character from the circularBuffer
    ; Add 1 to both indexes
    ; Divide circular index buffer by the size
    ; Set circular index buffer to the remainder

    push rbp
    
    ; Get the circular index character
    movsxd r13, dword[circularIndexWrite]
    mov r10b, byte[rsi + r13]

    ; See if it is a new line character
    cmp r10b, 10
    jne notNewLine
    
    ; Increment row and reset column if it is new line
    movsxd rbx, dword[rowNumber]
    inc rbx
    mov dword[rowNumber], ebx
    mov dword[columnNumber], 0
    jmp setLoopCompareString

    ; Increment column if it isn't a new line
    notNewLine:
        movsxd rbx, dword[columnNumber]
        inc rbx
        mov dword[columnNumber], ebx

    ; Get the string length to loop for comparison
    setLoopCompareString:
        call stringLength
        mov rcx, rax
        dec rcx

    ; Comapre the string to the cirular buffer string
    loopCompareString:
        movzx r9, byte[rdi]
        movzx r10, byte[rsi + r13]

        ; See if characters are equal
        cmp r9b, r10b
        jne stringNotMatch

        ; Move to the next characters
        inc rdi
        inc r13
        mov rax, r13
        mov rdx, 0
        movsxd rbx, dword[circularBufferSize]
        div rbx
        mov r13, rdx

    ; Loop back if the whole string hasn't been compared
    dec rcx
    cmp rcx, 0
    jne loopCompareString

        mov rbx, FALSE
        mov dword[resultsFileIsEmpty], ebx

        ; Update the row number in print out
        mov rdi, rowNumber
        mov rsi, printOut
        add rsi, 6
        call convertIntegerToHexadecimal

        ; Update the column number in print out
        mov rdi, columnNumber
        mov rsi, printOut
        add rsi, 25
        call convertIntegerToHexadecimal



        ; Print out to the file
        mov rdi, printOut
        call stringLength
        mov rdx, rax
        dec rdx
        mov rax, SYSTEM_WRITE
        mov rdi, qword[outputFileDescriptor]
        mov rsi, printOut
        syscall

        SystemWriteValid:

    stringNotMatch:
        ; Update the start of the circular buffer
        inc rdi
        inc rsi
        mov rdx, 0
        movsxd rax, dword[circularIndexWrite]
        div qword[circularBufferSize]
        inc edx
        mov dword[circularIndexWrite], edx

    pop rbp
ret
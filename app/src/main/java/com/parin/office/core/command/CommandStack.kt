package com.parin.office.core.command

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

fun interface EditCommand {
    fun apply()
    fun undo()
}

class CommandStack(private val maxDepth: Int = 250) {
    private val undoStack = ArrayDeque<EditCommand>()
    private val redoStack = ArrayDeque<EditCommand>()
    private val mutex = Mutex()

    suspend fun execute(command: EditCommand) = mutex.withLock {
        command.apply()
        undoStack.addLast(command)
        redoStack.clear()
        while (undoStack.size > maxDepth) undoStack.removeFirst()
    }

    suspend fun undo() = mutex.withLock {
        undoStack.removeLastOrNull()?.also {
            it.undo()
            redoStack.addLast(it)
        }
    }

    suspend fun redo() = mutex.withLock {
        redoStack.removeLastOrNull()?.also {
            it.apply()
            undoStack.addLast(it)
        }
    }

    suspend fun clear() = mutex.withLock {
        undoStack.clear()
        redoStack.clear()
    }

    fun canUndo() = undoStack.isNotEmpty()
    fun canRedo() = redoStack.isNotEmpty()
}

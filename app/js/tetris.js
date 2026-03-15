(function () {
    "use strict";

    const COLS = 10;
    const ROWS = 20;
    const BLOCK_SIZE = 30;
    const COLORS = [
        null,
        "#00f0ff", // I - cyan
        "#0000ff", // J - blue
        "#ff8c00", // L - orange
        "#ffff00", // O - yellow
        "#00ff00", // S - green
        "#9b00ff", // T - purple
        "#ff0000", // Z - red
    ];

    const SHAPES = [
        [],
        [[0,0,0,0],[1,1,1,1],[0,0,0,0],[0,0,0,0]], // I
        [[2,0,0],[2,2,2],[0,0,0]],                   // J
        [[0,0,3],[3,3,3],[0,0,0]],                   // L
        [[4,4],[4,4]],                                // O
        [[0,5,5],[5,5,0],[0,0,0]],                   // S
        [[0,6,0],[6,6,6],[0,0,0]],                   // T
        [[7,7,0],[0,7,7],[0,0,0]],                   // Z
    ];

    const canvas = document.getElementById("tetris");
    const ctx = canvas.getContext("2d");
    const nextCanvas = document.getElementById("next-piece");
    const nextCtx = nextCanvas.getContext("2d");

    const scoreEl = document.getElementById("score");
    const levelEl = document.getElementById("level");
    const linesEl = document.getElementById("lines");
    const finalScoreEl = document.getElementById("final-score");
    const startScreen = document.getElementById("start-screen");
    const gameOverScreen = document.getElementById("game-over");
    const startBtn = document.getElementById("start-btn");
    const restartBtn = document.getElementById("restart-btn");

    let board, piece, nextPiece, score, level, linesCleared, gameOver, paused, dropInterval, lastDrop;

    function createBoard() {
        return Array.from({ length: ROWS }, () => new Array(COLS).fill(0));
    }

    function randomPiece() {
        const id = Math.floor(Math.random() * 7) + 1;
        return {
            shape: SHAPES[id].map(row => [...row]),
            x: Math.floor(COLS / 2) - Math.ceil(SHAPES[id][0].length / 2),
            y: 0,
            id: id,
        };
    }

    function rotate(matrix) {
        const N = matrix.length;
        const result = matrix.map((row, i) => row.map((_, j) => matrix[N - 1 - j][i]));
        return result;
    }

    function collides(board, piece) {
        for (let y = 0; y < piece.shape.length; y++) {
            for (let x = 0; x < piece.shape[y].length; x++) {
                if (piece.shape[y][x] !== 0) {
                    const newX = piece.x + x;
                    const newY = piece.y + y;
                    if (newX < 0 || newX >= COLS || newY >= ROWS) return true;
                    if (newY >= 0 && board[newY][newX] !== 0) return true;
                }
            }
        }
        return false;
    }

    function merge(board, piece) {
        piece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    board[piece.y + y][piece.x + x] = value;
                }
            });
        });
    }

    function clearLines() {
        let cleared = 0;
        for (let y = ROWS - 1; y >= 0; y--) {
            if (board[y].every(cell => cell !== 0)) {
                board.splice(y, 1);
                board.unshift(new Array(COLS).fill(0));
                cleared++;
                y++;
            }
        }
        if (cleared > 0) {
            const points = [0, 100, 300, 500, 800];
            score += (points[cleared] || 800) * level;
            linesCleared += cleared;
            level = Math.floor(linesCleared / 10) + 1;
            dropInterval = Math.max(100, 1000 - (level - 1) * 80);
            updateUI();
        }
    }

    function updateUI() {
        scoreEl.textContent = score;
        levelEl.textContent = level;
        linesEl.textContent = linesCleared;
    }

    function drawBlock(context, x, y, colorIndex, size) {
        if (colorIndex === 0) return;
        const color = COLORS[colorIndex];
        context.fillStyle = color;
        context.fillRect(x * size, y * size, size - 1, size - 1);
        context.fillStyle = "rgba(255,255,255,0.2)";
        context.fillRect(x * size, y * size, size - 1, 3);
        context.fillRect(x * size, y * size, 3, size - 1);
    }

    function drawBoard() {
        ctx.fillStyle = "#111133";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        for (let y = 0; y < ROWS; y++) {
            for (let x = 0; x < COLS; x++) {
                if (board[y][x] !== 0) {
                    drawBlock(ctx, x, y, board[y][x], BLOCK_SIZE);
                } else {
                    ctx.strokeStyle = "rgba(255,255,255,0.03)";
                    ctx.strokeRect(x * BLOCK_SIZE, y * BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE);
                }
            }
        }
    }

    function drawPiece() {
        piece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    drawBlock(ctx, piece.x + x, piece.y + y, value, BLOCK_SIZE);
                }
            });
        });
    }

    function drawGhost() {
        let ghostY = piece.y;
        while (!collides(board, { ...piece, y: ghostY + 1 })) {
            ghostY++;
        }
        ctx.globalAlpha = 0.2;
        piece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    drawBlock(ctx, piece.x + x, ghostY + y, value, BLOCK_SIZE);
                }
            });
        });
        ctx.globalAlpha = 1;
    }

    function drawNext() {
        nextCtx.fillStyle = "transparent";
        nextCtx.clearRect(0, 0, nextCanvas.width, nextCanvas.height);
        const size = 25;
        const offsetX = (nextCanvas.width - nextPiece.shape[0].length * size) / 2;
        const offsetY = (nextCanvas.height - nextPiece.shape.length * size) / 2;

        nextPiece.shape.forEach((row, y) => {
            row.forEach((value, x) => {
                if (value !== 0) {
                    nextCtx.fillStyle = COLORS[value];
                    nextCtx.fillRect(offsetX + x * size, offsetY + y * size, size - 1, size - 1);
                }
            });
        });
    }

    function drop() {
        piece.y++;
        if (collides(board, piece)) {
            piece.y--;
            merge(board, piece);
            clearLines();
            piece = nextPiece;
            piece.x = Math.floor(COLS / 2) - Math.ceil(piece.shape[0].length / 2);
            piece.y = 0;
            nextPiece = randomPiece();
            drawNext();
            if (collides(board, piece)) {
                gameOver = true;
                finalScoreEl.textContent = score;
                gameOverScreen.classList.remove("hidden");
            }
        }
        lastDrop = performance.now();
    }

    function hardDrop() {
        while (!collides(board, { ...piece, y: piece.y + 1 })) {
            piece.y++;
            score += 2;
        }
        updateUI();
        drop();
    }

    function moveLeft() {
        piece.x--;
        if (collides(board, piece)) piece.x++;
    }

    function moveRight() {
        piece.x++;
        if (collides(board, piece)) piece.x--;
    }

    function rotatePiece() {
        const rotated = rotate(piece.shape);
        const prevShape = piece.shape;
        piece.shape = rotated;
        if (collides(board, piece)) {
            piece.x--;
            if (collides(board, piece)) {
                piece.x += 2;
                if (collides(board, piece)) {
                    piece.x--;
                    piece.shape = prevShape;
                }
            }
        }
    }

    function gameLoop(now) {
        if (gameOver) return;
        if (!paused) {
            if (now - lastDrop > dropInterval) {
                drop();
            }
            drawBoard();
            drawGhost();
            drawPiece();
        }
        requestAnimationFrame(gameLoop);
    }

    function startGame() {
        board = createBoard();
        score = 0;
        level = 1;
        linesCleared = 0;
        gameOver = false;
        paused = false;
        dropInterval = 1000;
        lastDrop = performance.now();
        piece = randomPiece();
        nextPiece = randomPiece();
        updateUI();
        drawNext();
        startScreen.classList.add("hidden");
        gameOverScreen.classList.add("hidden");
        requestAnimationFrame(gameLoop);
    }

    document.addEventListener("keydown", (e) => {
        if (gameOver) return;
        switch (e.key) {
            case "ArrowLeft":  e.preventDefault(); moveLeft(); break;
            case "ArrowRight": e.preventDefault(); moveRight(); break;
            case "ArrowDown":  e.preventDefault(); drop(); score += 1; updateUI(); break;
            case "ArrowUp":    e.preventDefault(); rotatePiece(); break;
            case " ":          e.preventDefault(); hardDrop(); break;
            case "p": case "P":
                paused = !paused;
                if (!paused) lastDrop = performance.now();
                break;
        }
    });

    startBtn.addEventListener("click", startGame);
    restartBtn.addEventListener("click", startGame);
})();

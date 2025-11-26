#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>      // For usleep()
#include <ncurses.h>     // For screen and input control on Linux/Unix

// --- 游戏设置 ---
// 注意: ncurses 使用 y, x (行, 列)
#define MAX_Y 20
#define MAX_X 40
#define INITIAL_LENGTH 3
#define TICK_DELAY 100000 // 游戏刷新延迟 (微秒 usleep)，100000 us = 100 ms

// --- 结构体定义 ---
typedef struct SnakeSegment {
    int x;
    int y;
} SnakeSegment;

// --- 全局变量 ---
SnakeSegment snake[MAX_Y * MAX_X]; // 蛇的身体
int snake_length;
int food_x, food_y;
int score;
char direction; // 'w', 's', 'a', 'd'
int game_over;

// --- 函数声明 ---
void Setup();
void Draw();
void Input();
void Logic();
void GenerateFood();
// Gotoxy() 被 ncurses 的 move() 函数替代
// Sleep() 被 ncurses 的 timeout() 和 usleep() 替代

// --- 主函数 ---
int main() {
    // 设置随机数种子
    srand(time(NULL));

    Setup();

    // ncurses 初始化
    initscr();              // 初始化 curses 模式
    cbreak();               // 禁用行缓冲，立即读取输入
    noecho();               // 不回显用户输入
    keypad(stdscr, TRUE);   // 启用功能键和方向键
    nodelay(stdscr, TRUE);  // 设置为非阻塞输入
    curs_set(0);            // 隐藏光标

    // 检查终端尺寸是否足够
    if (LINES < MAX_Y + 4 || COLS < MAX_X + 20) {
        endwin();
        fprintf(stderr, "终端太小! 请调整到至少 %dx%d.\n", MAX_X + 20, MAX_Y + 4);
        return 1;
    }

    // 绘制欢迎信息
    mvprintw(MAX_Y / 2, MAX_X / 2 - 10, "--- C语言简单贪吃蛇 ---");
    mvprintw(MAX_Y / 2 + 1, MAX_X / 2 - 10, "使用 W/A/S/D 控制方向");
    mvprintw(MAX_Y / 2 + 2, MAX_X / 2 - 10, "按任意键开始...");
    refresh();

    // 等待开始
    getch();

    while (!game_over) {
        Draw();
        Input();
        Logic();
        usleep(TICK_DELAY); // 游戏速度控制 (微秒)
    }

    // 游戏结束画面
    endwin(); // 退出 curses 模式，恢复终端

    printf("\n\n");
    printf("*********************************\n");
    printf("*** G A M E   O V E R !     ***\n");
    printf("*********************************\n");
    printf("      最终得分: %d\n", score);
    printf("*********************************\n");
    printf("\n按任意键退出...\n");

    // 等待用户输入后退出
    getchar();

    return 0;
}

// 初始化游戏
void Setup() {
    game_over = 0;
    score = 0;
    direction = 'd'; // 初始向右

    // 初始化蛇身
    snake_length = INITIAL_LENGTH;
    int center_x = MAX_X / 2;
    int center_y = MAX_Y / 2;

    for (int i = 0; i < snake_length; i++) {
        snake[i].x = center_x - i;
        snake[i].y = center_y;
    }

    GenerateFood();
}

// 生成食物
void GenerateFood() {
    int is_on_snake;
    do {
        is_on_snake = 0;
        // 随机生成食物位置 (确保在边界内)
        food_x = 1 + rand() % (MAX_X - 2);
        food_y = 1 + rand() % (MAX_Y - 2);

        // 检查食物是否与蛇身重合
        for (int i = 0; i < snake_length; i++) {
            if (snake[i].x == food_x && snake[i].y == food_y) {
                is_on_snake = 1;
                break;
            }
        }
    } while (is_on_snake);
}

// 绘制游戏界面
void Draw() {
    clear(); // 清空屏幕

    // 绘制上边框 和 分数
    move(0, 0);
    for (int i = 0; i < MAX_X; i++) {
        addch('#');
    }
    mvprintw(0, MAX_X + 2, "Score: %d", score);

    // 绘制中间部分
    for (int i = 1; i < MAX_Y - 1; i++) {
        for (int j = 0; j < MAX_X; j++) {
            // 定位到当前坐标
            move(i, j);

            if (j == 0 || j == MAX_X - 1) {
                addch('#'); // 左右边框
            } else {
                int is_drawn = 0;

                // 检查是否为蛇头
                if (j == snake[0].x && i == snake[0].y) {
                    addch('@');
                    is_drawn = 1;
                }
                // 检查是否为食物
                else if (j == food_x && i == food_y) {
                    addch('$');
                    is_drawn = 1;
                }
                // 检查是否为蛇身
                else {
                    for (int k = 1; k < snake_length; k++) {
                        if (j == snake[k].x && i == snake[k].y) {
                            addch('o');
                            is_drawn = 1;
                            break;
                        }
                    }
                }

                if (!is_drawn) {
                    addch(' '); // 空格
                }
            }
        }
    }

    // 绘制下边框
    move(MAX_Y - 1, 0);
    for (int i = 0; i < MAX_X; i++) {
        addch('#');
    }
    mvprintw(MAX_Y - 1, MAX_X + 2, "WASD控制 | 按X退出");

    refresh(); // 刷新屏幕显示
}

// 处理用户输入
void Input() {
    int ch = getch(); // 非阻塞获取输入

    // 限制方向不能立即反转
    switch (ch) {
        case 'w':
        case 'W':
            if (direction != 's') direction = 'w';
            break;
        case 's':
        case 'S':
            if (direction != 'w') direction = 's';
            break;
        case 'a':
        case 'A':
            if (direction != 'd') direction = 'a';
            break;
        case 'd':
        case 'D':
            if (direction != 'a') direction = 'd';
            break;
        case 'x':
        case 'X':
            game_over = 1; // 退出游戏
            break;
    }
}

// 更新游戏逻辑
void Logic() {
    // 1. 移动蛇身 (从尾部开始，每个节点移动到前一个节点的位置)
    for (int i = snake_length - 1; i > 0; i--) {
        snake[i] = snake[i - 1];
    }

    // 2. 移动蛇头
    switch (direction) {
        case 'w': snake[0].y--; break;
        case 's': snake[0].y++; break;
        case 'a': snake[0].x--; break;
        case 'd': snake[0].x++; break;
    }

    // 3. 检查碰撞：撞墙
    if (snake[0].x <= 0 || snake[0].x >= MAX_X - 1 ||
        snake[0].y <= 0 || snake[0].y >= MAX_Y - 1) {
        game_over = 1;
        return;
    }

    // 4. 检查碰撞：撞到自己
    for (int i = 1; i < snake_length; i++) {
        if (snake[0].x == snake[i].x && snake[0].y == snake[i].y) {
            game_over = 1;
            return;
        }
    }

    // 5. 检查食物：吃到食物
    if (snake[0].x == food_x && snake[0].y == food_y) {
        score += 10;

        // 增加蛇的长度
        if (snake_length < MAX_Y * MAX_X) {
            snake_length++;
            // 确保新的一节身体是在旧的尾部位置，防止绘制错误
            snake[snake_length - 1] = snake[snake_length - 2];
        }

        GenerateFood(); // 生成新的食物
    }
}
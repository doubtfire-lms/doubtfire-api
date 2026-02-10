#include "splashkit.h"

int main()
{
	string name;
	string favourite_tv_show;
	string favourite_meal;

	write_line("Welcome to the very basic bot experience!");
	write_line("Please answer using single words :)");
	delay(200);
	write_line("----------------------------------------");
	delay(200);
	write_line();

	delay(200);
	write_line("Bot: Hello! What's your name?");
	delay(200);
	write("> ");
	name = read_line();
	write_line("Bot: Hi " + name + ", nice to meet you!");

	delay(200);
	write_line("Bot: What's your favourite TV show?");
	delay(200);
	write("> ");
	favourite_tv_show = read_line();
	write_line("Bot: " + to_uppercase(favourite_tv_show) + "!? Umm... I don't like " + favourite_tv_show + " that much sorry.");

	delay(200);
	write_line("What about food? Favourite meal?");
	delay(200);
	write("> ");
	favourite_meal = read_line();
	write_line("Bot: " + to_lowercase(favourite_meal) + " is a better choice than " + to_lowercase(favourite_tv_show) + " at least...");

	delay(600);
	write_line("Anyway bye!");
	delay(200);
	write_line("\nThe bot has left the chat.");

	return 0;
}

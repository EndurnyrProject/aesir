defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Crayu do
  @moduledoc """
  A Niflheim bard who sings an old four-line song and quizzes Piano Key questers on it.

  ## Behavior

  - Always recites the song's four lines.
  - Players at the Crayu step of either key route must type a randomly chosen line; the right
    answer rewards a Piano Keyboard and advances the route, a wrong one changes nothing.
  - Anyone else hears him wonder about the song's secret.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nif_in",
        x: 105,
        y: 81,
        dir: 3,
        sprite: 794,
        name: "Crayu",
        scope: :shared,
        unique_name: "Crayu#nif"
      }
    ]

  @piano_keyboard 7184

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Crayu]")
      |> mes("Living one...")
      |> mes("Listen to this song...")
      |> mes("It's been sung by many for a")
      |> mes("long time, but nobody knows")
      |> mes("when it was made or who wrote it.")
      |> next()
      |> mes("[Crayu]")
      |> mes("^FF00001. Mountain sunset to the west")
      |> mes("^FF00002. Where the purple dusk falls ")
      |> mes("^FF00003. Surrounded by beautiful melody")
      |> mes("^FF00004. You become the key that ignores its master^000000")
      |> next()

    if get_char_var(ctx, :nif_esc, 0) in [1, 4], do: quiz(ctx), else: wonder(ctx)
  end

  defp quiz(ctx) do
    {song_line, prompt} = random_line()

    {ctx, answer} =
      ctx
      |> mes("[Crayu]")
      |> mes("Okay, wait! Here's a test for you!")
      |> mes(prompt)
      |> next()
      |> input(:string)

    if answer == song_line, do: reward(ctx), else: wrong_answer(ctx)
  end

  defp random_line do
    case Enum.random(1..4) do
      1 ->
        {"Mountain sunset to the west", "Write down the first line of the song."}

      2 ->
        {"Where the purple dusk falls", "Write down the second line of the song."}

      3 ->
        {"Surrounded by beautiful melody", "Write down the third line of the song."}

      4 ->
        {"You become the key that ignores its master", "Write down the fourth line of the song."}
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Crayu]")
      |> mes("Excellent...!")
      |> mes("So you've been listening~!")
      |> mes("That makes you one of my")
      |> mes("favorite guests. Here's a")
      |> mes("little reward for you.")
      |> next()

    next_step = if get_char_var(ctx, :nif_esc, 0) == 1, do: 3, else: 6

    ctx
    |> set_char_var(:nif_esc, next_step)
    |> give_item(@piano_keyboard, 1)
    |> mes("[Crayu]")
    |> mes("Lastly, I hope you will show your")
    |> mes("respect to other Bards, just as")
    |> mes("you have done for me.")
    |> close()
  end

  defp wrong_answer(ctx) do
    ctx
    |> mes("[Crayu]")
    |> mes("*Sigh*... If you had only")
    |> mes("listened to me, it would")
    |> mes("have been easy to answer.")
    |> mes("Try to remember the line")
    |> mes("and try again!")
    |> close()
  end

  defp wonder(ctx) do
    ctx
    |> next()
    |> mes("[Crayu]")
    |> mes("I wonder what the lyrics mean...")
    |> mes("They seem quite profound...")
    |> mes("I have the feeling that this song")
    |> mes("carries some secret.")
    |> close()
  end
end

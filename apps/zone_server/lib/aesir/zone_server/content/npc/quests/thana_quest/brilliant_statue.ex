defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.BrilliantStatue do
  @moduledoc """
  A magical statue yields the Blue Key when its two locks are opened.

  ## Behavior

  - Requires the red and yellow keys and their names to release the Blue Key.
  - Reveals a vision and advances the tower quest at the appropriate stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t05",
        x: 62,
        y: 179,
        dir: 0,
        sprite: 111,
        name: "Brilliant Statue",
        scope: :shared,
        unique_name: "Brilliant Statue#tt3",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    if missing_blue_key?(ctx), do: specialeffect(ctx, :level99_4), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if missing_blue_key?(ctx) do
      investigate(ctx)
    else
      ctx |> mes("You've acquired everything you need from this statue.") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp missing_blue_key?(ctx), do: count_item(ctx, 7423) == 0 and count_item(ctx, 7428) == 0

  defp investigate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I can feel some magical power from this beautiful stone statue.")
      |> mes("There's a little crack between the wings.")
      |> next()
      |> mes(
        "Red light is shining on a crack in the left wing, and gold light on a crack in the right one."
      )
      |> mes("What will you do?")
      |> next()
      |> select(["Stick the key into the crack...", "Ignore it."])

    cond do
      choice == 2 ->
        ctx |> mes("^3355FFYou decide to leave") |> mes("the statue alone.^000000") |> close()

      count_item(ctx, 7421) > 0 and count_item(ctx, 7422) > 0 ->
        left_wing(ctx)

      true ->
        ctx |> mes("You try to fit something in the crack, but to no avail.") |> close()
    end
  end

  defp left_wing(ctx) do
    {ctx, key} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'll try the left wing first.")
      |> mes("What key should I put in?")
      |> next()
      |> input(:string)

    if key in ["Red Key", "red key"] do
      right_wing(ctx)
    else
      wrong_key(ctx)
    end
  end

  defp right_wing(ctx) do
    {ctx, key} =
      ctx
      |> mes("The key fits and makes a click.")
      |> mes("You feel the magical power growing stronger...")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Now the right side...")
      |> next()
      |> input(:string)

    if key in ["Yellow Key", "yellow key"] do
      release_key(ctx)
    else
      wrong_key(ctx)
    end
  end

  defp wrong_key(ctx), do: ctx |> mes("It doesn't fit into the crack.") |> close()

  defp release_key(ctx) do
    ctx =
      ctx
      |> mes("The key fits and makes a click.")
      |> mes("The beak of the bird suddenly opens, and a strong light comes out.")
      |> mes("There's a key-shaped object inside...")
      |> next()
      |> mes("^4d4dffThe powerful Blue Key appears.^000000")
      |> give_item(7423, 1)

    if get_char_var(ctx, :thana_tower, 0) == 6, do: vision(ctx), else: close(ctx)
  end

  defp vision(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^4d4dffOnce you hold the key, a shocking feeling passes through your head.")
      |> mes("You see an illusion of light...^000000")
      |> next()
      |> select(["Concentrate on it.", "Ignore it."])

    case choice do
      1 ->
        ctx
        |> mes("This part isn't as clear as before.")
        |> mes("You try to figure out what it's saying...")
        |> next()
        |> mes("^b22222...this tower was built by a magical tribe, not by human beings.")
        |> mes("This was quite interesting to me...")
        |> mes("I started to investigate why they built up the tower...")
        |> next()
        |> mes("^b22222I found out that this tower was a gate for the magic tribe")
        |> mes("during a millennium war.^000000")
        |> next()
        |> mes(".........It's not clearly shown......")
        |> mes("^b22222...Morocc has gone through this gate")
        |> mes(
          "from the magical world into the Midgard continent after the millennium war terminated..."
        )
        |> next()
        |> mes(
          "^b22222The question is that when she come up here, the Satan appears at the same time..."
        )
        |> mes("The truth is..........^000000")
        |> next()
        |> mes("The illusion shakes, then melts on the surface of the key as light.")
        |> set_char_var(:thana_tower, 7)
        |> changequest(7050, 7051)
        |> specialeffect2(:comboattack1)
        |> close()

      2 ->
        ctx |> mes("You decide to ignore it.") |> close()

      _ ->
        ctx
    end
  end
end

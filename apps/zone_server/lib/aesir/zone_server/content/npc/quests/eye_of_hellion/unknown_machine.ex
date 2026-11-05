defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.UnknownMachine do
  @moduledoc """
  An old machine hides a tablet behind a numeric password.

  ## Behavior

  - Checks inventory capacity before allowing interaction.
  - Consumes a cogwheel to activate the keypad and awards a tablet for the correct password.
  - Allows retrying the password after activation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 128,
        y: 79,
        dir: 0,
        sprite: 111,
        name: "Unknown Machine",
        scope: :shared,
        unique_name: "Unknown Machine#prt_key"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    step = get_char_var(ctx, :HELLIONQ, 0)

    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 or
          checkweight(ctx, [{1201, 1}]) == 0 ->
        capacity_warning(ctx)

      step == 43 ->
        inspect_machine(ctx)

      step == 44 ->
        retry_password(ctx)

      true ->
        ctx
        |> mes("^3355FFIt's some sort of")
        |> mes("strange looking machine")
        |> mes("with a mysterious purpose.^000000")
        |> close()
    end
  end

  defp capacity_warning(ctx) do
    ctx
    |> mes("^3355FFHold it right there!")
    |> mes(
      "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
    )
    |> close()
  end

  defp inspect_machine(ctx) do
    ctx =
      ctx
      |> mes("^3355FFIt's a weird looking")
      |> mes("machine that looks like")
      |> mes("it hasn't been used in a")
      |> mes("while. It looks like the")
      |> mes("cogwheel that you have")
      |> mes("would fit perfectly in it...^000000")
      |> next()

    if count_item(ctx, 7093) > 0 do
      {ctx, choice} = select(ctx, ["Insert Cogwheel.", "Ignore it."])
      if choice == 1, do: insert_cogwheel(ctx), else: ignore_machine(ctx)
    else
      missing_cogwheel(ctx)
    end
  end

  defp insert_cogwheel(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I just know this")
      |> mes("cogwheel will fit")
      |> mes("into this machine!")
      |> mes("What I don't know is")
      |> mes("what will happen once")
      |> mes("this machine works...")
      |> next()
      |> mes("^3355FF*Click...!*")
      |> mes("Once the cogwheel is")
      |> mes("fit into the machine and")
      |> mes("turned, the device hums")
      |> mes("to life and a panel opens,")
      |> mes("revealing a numeric keypad.^000000")
      |> delitem(7093, 1)
      |> set_char_var(:HELLIONQ, 44)
      |> next()

    {ctx, password} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I guess that I've got")
      |> mes("to input some kind of")
      |> mes("numeric password...")
      |> mes("Ah, right, the numbers")
      |> mes("that Veggie Lady gave me!")
      |> next()
      |> input(:string)

    check_password(ctx, password, false)
  end

  defp retry_password(ctx) do
    {ctx, password} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Okay, let me see")
      |> mes("if I can enter the")
      |> mes("right number this time...")
      |> next()
      |> input(:string)

    check_password(ctx, password, true)
  end

  defp check_password(ctx, password, retry?) do
    if password == "3847147298" do
      ctx
      |> mes("^3355FFThe machine responds to")
      |> mes("the password with a pleasant")
      |> mes("chime, confirming that you've")
      |> mes("input the correct numbers.")
      |> mes("The keypad slides open to")
      |> mes("reveal a piece of a tablet.^000000")
      |> next()
      |> mes("^3355FFThe message engraved on")
      |> mes("this tablet reads: ''This is for")
      |> mes("Christopher, my dear friend")
      |> mes("who I met in Prontera. To the")
      |> mes("one who finds this, please seek")
      |> mes("out the next piece of this tablet")
      |> mes("in the city of thickest forest.''^000000")
      |> next()
      |> mes("^3355FFThe message is signed")
      |> mes("by someone named Tyus.")
      |> mes("It would be best to bring")
      |> mes("this back to Sir Chilia'Tyus")
      |> mes("and confirm that this was")
      |> mes("made by his grandfather...^000000")
      |> set_char_var(:HELLIONQ, 45)
      |> give_item(7333, 1)
      |> close()
    else
      ctx =
        if retry?,
          do: mes(ctx, "[#{char_name(ctx, 0)}]"),
          else: ctx

      ctx
      |> mes("The machine responds to")
      |> mes("the password with an abrupt,")
      |> mes("screeching beep and the entire")
      |> mes("machine shuts down. You'll have to try entering the password again.")
      |> close()
    end
  end

  defp ignore_machine(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Eh...")
    |> mes("Forget it.")
    |> close()
  end

  defp missing_cogwheel(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Uh oh...")
    |> mes("Where did I put")
    |> mes("the cogwheel that")
    |> mes("Clanux Heffron gave me?")
    |> close()
  end
end

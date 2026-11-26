defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Crayu do
  @moduledoc """
  Crayu guides an adventurer through Niflheim.

  ## Behavior

  - Shares a verse and, later, directs the adventurer to Gen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixed the unreachable reminder check from sign_q == 86 to sign_q == 87.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nif_in",
        x: 102,
        y: 81,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#Crayu",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    stage = get_char_var(ctx, :sign_q, 0)

    cond do
      stage < 75 ->
        ctx

      stage < 82 ->
        ctx
        |> mes("[Crayu]")
        |> mes("Mountain sunset to the west")
        |> mes("Where the purple dusk falls ")
        |> mes("Surrounded by beautiful melody")
        |> mes("^You become the key that ignores its master")
        |> close()

      stage == 86 ->
        ask_about_serin(ctx)

      stage == 87 ->
        ctx
        |> mes("Hmm...")
        |> mes("I think it would")
        |> mes("be a good idea if")
        |> mes("you talk to someone")
        |> mes("in Niflheim named ^FF0000Gen^000000.")
        |> close()

      true ->
        ctx
    end
  end

  defp ask_about_serin(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Crayu]")
      |> mes("Mountain sunset to the west")
      |> mes("Where the purple dusk falls ")
      |> mes("Surrounded by beautiful melody")
      |> mes("You become the key that ignores its master")
      |> next()
      |> mes("[Crayu]")
      |> mes("Hello adventurer.")
      |> mes("I know this is rather")
      |> mes("abrupt, but what do")
      |> mes("you think of Serin?")
      |> next()
      |> select(["She's good.", "She's evil!", "She could go either way."])

    {ctx, reason} =
      ctx
      |> mes("[Crayu]")
      |> mes("Hm...?")
      |> mes("And why do")
      |> mes("you think so?")
      |> next()
      |> select(["Just my opinion.", "It's the truth!"])

    case reason do
      1 ->
        score = get_char_var(ctx, :sign_sq, 0)
        ctx = set_char_var(ctx, :sign_sq, if(score > 1, do: 0, else: score + 1))
        explain_niflheim(ctx)

      2 ->
        explain_niflheim(ctx)

      _ ->
        ctx
    end
  end

  defp explain_niflheim(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Crayu]")
      |> mes("Ah, I understand.")
      |> mes("Now, how may I help you?")
      |> next()
      |> select(["What exactly is Niflheim?", "How do I become one of the chosen?"])

    case choice do
      1 ->
        ctx
        |> mes("[Crayu]")
        |> mes("Niflheim is commonly")
        |> mes("known as the city of the")
        |> mes("dead, but it's also the")
        |> mes("resting place of warriors")
        |> mes("who failed to enter Valhalla.")
        |> next()
        |> mes("[Crayu]")
        |> mes("Some heroes may think")
        |> mes("of Niflheim as the tragic end,")
        |> mes("but it really all depends on")
        |> mes("your point of view.")
        |> close()

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What do I need")
        |> mes("to do to become one")
        |> mes("of the chosen warriors?")
        |> next()
        |> mes("[Crayu]")
        |> mes("First and foremost,")
        |> mes("you must prove your courage.")
        |> mes("It will be up to you to decide")
        |> mes("how you will demonstrate your")
        |> mes("bravery. The gods will only")
        |> mes("be watching and judging.")
        |> next()
        |> mes("[Crayu]")
        |> mes("Hmm...")
        |> mes("I think it would")
        |> mes("be a good idea if")
        |> mes("you talk to someone")
        |> mes("in Niflheim named ^FF0000Gen^000000.")
        |> set_char_var(:sign_q, 87)
        |> close()

      _ ->
        ctx
    end
  end
end

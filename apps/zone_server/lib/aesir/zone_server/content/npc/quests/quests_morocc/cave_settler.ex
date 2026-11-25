defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.CaveSettler do
  @moduledoc """
  A cave guard controls access to Zid.

  ## Behavior

  - Challenges outsiders and permits those seeking Eva to pass.
  - Reacts differently when approached after the encounter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cave",
        x: 82,
        y: 97,
        dir: 3,
        sprite: 996,
        name: "Cave Settler",
        scope: :shared,
        unique_name: "Cave Settler#g1",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx), do: approach(ctx, :touch)

  @impl true
  def on_talk(ctx), do: approach(ctx, :talk)

  defp approach(ctx, entry) do
    progress = get_char_var(ctx, :barmunt_crow, 0)

    cond do
      progress == 8 ->
        challenge(ctx, entry)

      progress < 8 ->
        turn_away(ctx)

      entry == :touch ->
        ctx

      true ->
        ctx
        |> mes("[Cave Settler]")
        |> mes("Do you still have business with Zid?")
        |> mes(
          "You'd better finish it quickly because we don't like outsiders running around our village."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Cave Settler]")
    |> mes("No outsiders are allowed beyond this point.")
    |> next()
    |> mes("^660000His voice is as stern and intimidating as his appearance.^000000")
    |> close2()
    |> warp("cave", 81, 92)
  end

  defp challenge(ctx, entry) do
    {ctx, choice} =
      ctx
      |> mes("[Cave Settler]")
      |> mes("No outsiders are allowed beyond this point.")
      |> next()
      |> select(["Step back.", "No, listen to me!"])

    case choice do
      1 ->
        ctx
        |> mes("[Cave Settler]")
        |> mes("Hah, I knew you would be scared of me!")
        |> close2()
        |> warp("cave", 81, 92)

      2 ->
        explain_search(ctx, entry)

      _ ->
        ctx
    end
  end

  defp explain_search(ctx, entry) do
    description =
      case entry do
        :talk ->
          "^660000Although you a bit intimidated by this guard, and your sneezing definitely not helping, you continue.^000000"

        :touch ->
          "^660000Although you're a bit intimidated by this guard, and your sneezing definitely not helping, you continue.^000000"
      end

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah... Ahchoo!")
      |> mes("'I'm not like other outsiders... Ahchoo!")
      |> mes("I have a goal to achieve in here... Ahchoo!")
      |> specialeffect2(:venomdust)
      |> next()
      |> mes(description)
      |> next()

    {ctx, name} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm here to find somebody!")
      |> input(:string)

    ctx = set_local(ctx, :"input$", name)

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("Her name is ^FF0000", get_local(ctx, :"input$", "")),
          "^000000!"
        )
      )
      |> next()

    if Rathena.compare(get_local(ctx, :"input$", ""), "Eva") == 0 do
      ctx
      |> mes("[Cave Settler]")
      |> mes(
        "Are you kidding me? If you're looking for a missing child, go to the Juno police station!"
      )
      |> close2()
      |> warp("cave", 81, 92)
    else
      ctx
      |> mes("[Cave Settler]")
      |> mes("............!!!!")
      |> next()
      |> mes("[Cave Settler]")
      |> mes("Did you just say Eva?")
      |> mes("Hmm...")
      |> mes("Wait here.")
      |> next()
      |> emotion(:comeon)
      |> mes("[Cave Settler]")
      |> mes("Hey, Jaeda!")
      |> enablenpc("Jaeda#garas1")
      |> next()
      |> mes("[Cave Settler]")
      |> mes("Go upstairs, and tell Eva that she has a visitor.")
      |> disablenpc("Jaeda#garas1")
      |> next()
      |> mes(
        "^660000Surprisingly, he seemed to know who Eva is. You still could not believe that she actually exists! It's all so very strange.^000000"
      )
      |> next()
      |> mes(
        "^660000You can feel the excitement and anticipation well within you. Maybe you're coming closer to learning what your dreams really mean.^000000"
      )
      |> enablenpc("Jaeda#garas1")
      |> next()
      |> mes("[Cave Settler]")
      |> mes("Hmm... Yeah? I see.")
      |> next()
      |> disablenpc("Jaeda#garas1")
      |> mes("[Cave Settler]")
      |> mes(
        "Hey, you can pass. Go upstairs, but you'd better think twice before trying anything funny. Do you understand me?"
      )
      |> next()
      |> mes(
        "^660000The stern-looking man examined you, and then stepped to the side, allowing you to pass."
      )
      |> mes(
        "You clenched your fists in nervousness, and then started up the dark stairwell.^000000"
      )
      |> set_char_var(:barmunt_crow, 9)
      |> close2()
      |> warp("cave", 82, 105)
    end
  end
end

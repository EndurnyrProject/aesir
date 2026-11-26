defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Treasure do
  @moduledoc """
  A buried chest holds a magically protected treasure.

  ## Behavior

  - Requires the correct spell and a companion to recover its cursed contents.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild18",
        x: 108,
        y: 116,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#treasure"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 300}]) == 0 ->
        ctx
        |> mes("^3355FFYou're carrying too many")
        |> mes("items: there's no way you")
        |> mes("can carry the Treasure")
        |> mes("Chest with you for now.^000000")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) == 5 ->
        ctx =
          ctx
          |> mes("^3355FFThere's something")
          |> mes("here, buried just")
          |> mes("beneath the ground.^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Unngh! I-it won't...!")
        |> next()
        |> mes("^3355FFNo matter how hard")
        |> mes("you try, you can't dig")
        |> mes("out the chest or open it.")
        |> mes("There's some magical")
        |> mes("aura surrounding the chest")
        |> mes("that might be stopping you.^000000")
        |> set_char_var(:treasure_nd, 6)
        |> close()

      get_char_var(ctx, :treasure_nd, 0) == 6 ->
        ctx
        |> mes("^3355FFThat Treasure Hunter in")
        |> mes("Morocc must know something")
        |> mes("about the chest's magical")
        |> mes("protection. It might be")
        |> mes("a good idea to ask him.^000000")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) in [7, 8] ->
        ctx
        |> mes("^3355FFYou tried casting the")
        |> mes("spell on the document")
        |> mes("you received, but nothing")
        |> mes("happened. You should probably")
        |> mes("find the other man over in")
        |> mes("Comodo to see what he knows.^000000")
        |> close()

      get_char_var(ctx, :treasure_nd, 0) in [9, 10] ->
        open_chest(ctx)

      get_char_var(ctx, :treasure_nd, 0) == 11 and get_char_var(ctx, :zdan_edq, 0) > 0 ->
        ctx
        |> mes("^3355FFSomone must have")
        |> mes("checked the treasure")
        |> mes("site after you left:")
        |> mes("whoever it was left")
        |> mes("telltale signs of")
        |> mes("his presence.^000000")
        |> set_char_var(:treasure_nd, 12)
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp open_chest(ctx) do
    {ctx, spell} =
      ctx
      |> mes("^3355FFYou'll need to combine")
      |> mes("the two halves of the spell")
      |> mes("on the document you received")
      |> mes("to remove the chest's magical")
      |> mes("protection to get the treasure.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", spell)
    {ctx, _} = getpartymember(ctx, getcharid(ctx, 1))
    ctx = set_local(ctx, :partymembercount, get_server_temp_var(ctx, "partymembercount", 0))

    cond do
      get_local(ctx, :partymembercount, 0) <= 1 ->
        ctx
        |> mes("^3355FFThe treasure chest still")
        |> mes("won't open. Then again,")
        |> mes("this doesn't seem to be")
        |> mes("a one man job...^000000")
        |> close()

      (get_local(ctx, :"input$", "") == "OpenSesame" and get_char_var(ctx, :treasure_nd, 0) == 9) or
          (get_local(ctx, :"input$", "") == "UnlockTreasure" and
             get_char_var(ctx, :treasure_nd, 0) == 10) ->
        claim_treasure(ctx)

      true ->
        ctx
        |> mes("^3355FFNothing happened.")
        |> mes("You might not be")
        |> mes("combining the spell")
        |> mes("correctly. Perhaps if")
        |> mes("you made it all one word...^000000")
        |> close()
    end
  end

  defp claim_treasure(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThe Z Gang must have split")
      |> mes("the spell document in two")
      |> mes("parts because one person")
      |> mes("isn't enough to open this")
      |> mes("chest. It's a good thing")
      |> mes("you brought a friend.^000000")
      |> next()
      |> mes("^3355FFYou cast the spell,")
      |> mes("the chest opens, and")
      |> mes("you grab all the loot inside.^000000")

    ctx =
      set_char_var(ctx, :treasure_nd, if(get_char_var(ctx, :zdan_edq, 0) == 0, do: 11, else: 12))

    ctx =
      ctx
      |> give_item(7725, 1)
      |> give_item(604, 1)
      |> give_item(1157, 1)
      |> sc_start(:sc_curse, 10000, 0)
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("N-no! What's going on?")
    |> mes("This Emerald... It must")
    |> mes("be cursed by evil magic!")
    |> close()
  end
end

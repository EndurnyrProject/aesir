defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Martha do
  @moduledoc """
  Martha confronts the player at the Z Gang hideout.

  ## Behavior

  - The encounter awards the stolen book and clears the hideout at the appropriate quest stage.
  - Otherwise, it returns the player outside.

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
    spawn: [%{map: "z_agit", x: 99, y: 101, dir: 3, sprite: 101, name: "Martha", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Martha]")
        |> mes("Hey, you're carrying")
        |> mes("too much stuff. You'd")
        |> mes("better put some of your")
        |> mes("items away first in Kafra")
        |> mes("Storage or something.")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 17 ->
        ctx =
          ctx
          |> mes("[Martha]")
          |> mes("Argh...! What'd ")
          |> mes("you do, Louis?")
          |> next()
          |> mes("[Louis]")
          |> mes("What happened?")
          |> mes("The big guns were")
          |> mes("supposed to come out!")
          |> mes("Why aren't we invisible")
          |> mes("anymore? What happened?")
          |> next()
          |> mes("[Catfoii]")
          |> mes("You pushed the button")
          |> mes("to turn off the invisibility,")
          |> mes("meow! Did you really have")
          |> mes("to ask?! It's your fault!")
          |> next()
          |> mes("[Martha]")
          |> mes("Argh! I should never")
          |> mes("have trusted that fool!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("So... Z Gang...")
          |> mes("And cat. It's time")
          |> mes("to turn you in.")
          |> next()
          |> mes("[Louis]")
          |> mes("I... I can't accept")
          |> mes("our defeat! The Z Gang")
          |> mes("won't go down so easily!")
          |> mes("Come forth, my demon")
          |> mes("spawn minions of doom!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I don't think")
          |> mes("they're coming.")
          |> next()
          |> mes("[Louis]")
          |> mes("...............................")
          |> mes("We surrender. Argh, but")
          |> mes("we were so close to")
          |> mes("conquering the world!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Now if you'll just")
          |> mes("hand over the Book")
          |> mes("of Forbidden Mystery...")
          |> next()
          |> mes("[Catfoii]")
          |> mes("Louis, meow!")
          |> mes("Don't do it!")
          |> next()
          |> mes("[Martha]")
          |> mes("Let's just surrender,")
          |> mes("Louis. It looks like")
          |> mes("the Z Gang is finished.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Anyway, the Rogue Guild")
        |> mes("is on its way to come get")
        |> mes("you guys. You won't be able")
        |> mes("to escape this time.")
        |> next()
        |> mes("[Louis]")
        |> mes("Awwww, man!")
        |> mes("Fine, take the stupid")
        |> mes("ol' book. I couldn't")
        |> mes("use it that good anyway.")
        |> next()
        |> mes("[Louis]")
        |> mes("Catfoii, would you")
        |> mes("lead this adventurer guy")
        |> mes("to the exit? I can't bear")
        |> mes("to look at the face that's")
        |> mes("caused my tragic downfall...")
        |> next()
        |> mes("[Catfoii]")
        |> mes("Fine, meow.")
        |> mes("I understand.")
        |> mes("But how did we lose?!")
        |> close2()
        |> give_item(7724, 1)
        |> changequest(3133, 3134)
        |> set_char_var(:zdan_edq, 18)
        |> mapwarp("z_agit", "moc_fild17", 209, 235)
        |> set_server_temp_var("monster_zgang", 0)
        |> set_server_temp_var("door2", 0)
        |> hideonnpc("Louis")
        |> hideonnpc("Martha")
        |> hideonnpc("Catfoii")
        |> disablenpc("#zdan_broad")
        |> stopnpctimer()
        |> close()

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Where am I...?")
        |> mes("Something has gone")
        |> mes("terribly wrong, hasn't")
        |> mes("it? Let me go baaaack~! ")
        |> set_char_var(:zdan_edq, 15)
        |> set_server_temp_var("monster_zgang", 0)
        |> set_server_temp_var("door2", 0)
        |> close2()
        |> warp("moc_fild17", 209, 235)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ev_oninit(ctx) do
    hideonnpc(ctx, "Martha")
  end
end

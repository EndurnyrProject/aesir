defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Hiddenactivator do
  @moduledoc """
  An unseen conversation reveals Thierry's research to the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "odin_tem01",
        x: 129,
        y: 127,
        dir: 0,
        sprite: 139,
        name: "HiddenActivator",
        scope: :shared,
        unique_name: "HiddenActivator#Hugel",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: on_talk(ctx)
  def on_event("OnTimer180000", ctx), do: disable_young_man(ctx)
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Young Man#Hu_Quest")

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_ma1, 0) do
      8 -> overhear_conversation(ctx)
      stage when stage in 9..11 -> enable_young_man(ctx)
      _ -> disable_young_man(ctx)
    end
  end

  defp overhear_conversation(ctx) do
    ctx
    |> mes("^3355FFYou can hear two")
    |> mes("people talking to")
    |> mes("each other a short")
    |> mes("distance away.^000000")
    |> next()
    |> mes("[Suspicious Man]")
    |> mes("You sure your research")
    |> mes("is progressing? I haven't")
    |> mes("seen anything that even")
    |> mes("resembles real results!")
    |> next()
    |> mes("[Young Man]")
    |> mes("I'm telling you, this isn't")
    |> mes("like the last project. There's")
    |> mes("no other way around it, it's")
    |> mes("going to take some time.")
    |> mes("You just have to be patient...")
    |> next()
    |> mes("[Suspicious Man]")
    |> mes("Fine. That's fine by me.")
    |> mes("But what about your fiancee?")
    |> mes("I know she's near death's door:")
    |> mes("can you really afford to wait")
    |> mes("this long? Think about it.")
    |> next()
    |> mes("[Young Man]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Suspicious Man]")
    |> mes("Just finish this as")
    |> mes("soon as you can. For")
    |> mes("your fiancee's sake.")
    |> mes("And your own sake.")
    |> mes("Catch my meaning?")
    |> next()
    |> mes("[Young Man]")
    |> mes("...I understand.")
    |> next()
    |> mes("^3355FFYou hear the sound of")
    |> mes("footsteps steadily becoming")
    |> mes("fainter and fainter. One of the")
    |> mes("men must be walking away.^000000")
    |> close()
    |> enablenpc("Young Man#Hu_Quest")
    |> initnpctimer()
  end

  defp enable_young_man(ctx), do: ctx |> enablenpc("Young Man#Hu_Quest") |> initnpctimer()
  defp disable_young_man(ctx), do: ctx |> disablenpc("Young Man#Hu_Quest") |> stopnpctimer()
end

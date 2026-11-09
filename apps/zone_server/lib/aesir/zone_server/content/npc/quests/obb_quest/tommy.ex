defmodule Aesir.ZoneServer.Content.Npc.Quests.ObbQuest.Tommy do
  @moduledoc """
  Tommy reacts to his father and the adventurer throughout the Old Blue Box quest.

  ## Behavior

  - Demands a Munak and reacts to the adventurer reassuring or upsetting him.
  - Learns to appreciate his father after their attempt to catch a Munak.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celesta
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/obb_quest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 107,
        y: 62,
        dir: 0,
        sprite: 716,
        name: "Tommy",
        scope: :shared,
        unique_name: "Tommy#thai"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :thai_head, 0) do
      6 -> demand_munak(ctx)
      7 -> cry_for_munak(ctx)
      8 -> reject_daddy(ctx)
      9 -> anticipate_munak(ctx)
      10 -> celebrate_munak(ctx)
      11 -> thank_adventurer(ctx)
      stage when stage > 11 -> appreciate_daddy(ctx)
      _ -> enjoy_family_walk(ctx)
    end
  end

  defp demand_munak(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Wahhhhhh~~~!!")
    |> mes("Daddy~~ let me have a Munak~~~!")
    |> mes("Waaaahhhh....")
    |> next()
    |> mes("[Tommy]")
    |> mes("I want my Munak~~!!")
    |> mes("Other people have one, why can't I have one too?!")
    |> next()
    |> mes("[Tommy]")
    |> mes("Munak Munak Munak Munak~~~")
    |> next()
    |> mes("[Jacob]")
    |> mes("Umm..Tommy...")
    |> next()
    |> mes("[Tommy]")
    |> mes("Munak Munak Munak Munak~~~")
    |> next()
    |> mes("[Jacob]")
    |> mes("Tommy, your daddy is kind of busy now...")
    |> next()
    |> mes("[Tommy]")
    |> mes("Munak Munak Munak Munak!")
    |> next()
    |> mes("[Jacob]")
    |> mes("Sigh...alright, alright...")
    |> close()
  end

  defp cry_for_munak(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("*cries*...I want Munak!....*cries*")
    |> mes("My friends all have Munak, and I don't have it...")
    |> mes("Waaaahhhhh~~")
    |> close()
  end

  defp reject_daddy(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Daddy, I hate you!!")
    |> mes("I hate all of you!!!")
    |> next()
    |> mes("[Tommy]")
    |> mes("Waaaahhh~~~!")
    |> mes("I don't care what anybody's telling")
    |> mes("me! I'll be bad because I hate everyone!")
    |> close()
  end

  defp anticipate_munak(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Heh~!")
    |> mes("I'm so happy~")
    |> mes("We're gonna get a Munak~!")
    |> mes("Heh heh heh~!")
    |> close()
  end

  defp celebrate_munak(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Heh~!")
    |> mes("I am so happy~")
    |> mes("We're gonna get a Munak~!")
    |> mes("Heh heh heh~!")
    |> close()
  end

  defp thank_adventurer(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Heh~!")
    |> mes("I like you~ ")
    |> mes("Cuz now we're gonna")
    |> mes("get a Munak~")
    |> mes("So happy! *smiles*")
    |> close()
  end

  defp appreciate_daddy(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("Daddy...I won't ask you for something that's too hard for you.")
    |> next()
    |> mes("[Tommy]")
    |> mes("I saw you're huffing and puffing when we went to catch a Munak.")
    |> mes("I'm so sorry that I gave you a hard time, daddy...")
    |> next()
    |> mes("[Tommy]")
    |> mes("I will be good from now on.")
    |> mes("I will be nice to my Daddy, to you and to anyone.")
    |> next()
    |> mes("[Tommy]")
    |> mes("My dad told me that I will be a good kid if I don't behave bad sometimes.")
    |> close()
  end

  defp enjoy_family_walk(ctx) do
    ctx
    |> mes("[Tommy]")
    |> mes("I hate to see my daddy resting in his room all day in the weekends.")
    |> mes("But I am so happy today because my daddy and I will take a walk together!!")
    |> close()
  end
end

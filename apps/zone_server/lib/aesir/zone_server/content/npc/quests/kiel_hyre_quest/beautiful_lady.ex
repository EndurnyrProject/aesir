defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BeautifulLady do
  @moduledoc """
  Allysia checks whether a visitor can be trusted as Elly’s friend.

  ## Behavior

  - The Golden Key answer grants access to her room without checking inventory.
  - The Carved Button answer summons four bombs; later quest progress grants access directly.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 119,
        y: 149,
        dir: 4,
        sprite: 894,
        name: "Beautiful Lady",
        scope: :shared,
        unique_name: "BeatifulLadyKHQ1"
      },
      %{
        map: "kh_school",
        x: 121,
        y: 149,
        dir: 4,
        sprite: 894,
        name: "Beautiful lady",
        scope: :shared,
        unique_name: "Beautiful lady#kh5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = cutin(ctx, "kh_ellisia", 2)

    if get_char_var(ctx, :KielHyreQuest, 0) < 40 do
      identify_friend(ctx)
    else
      ctx
      |> mes("[Allysia]")
      |> mes("Please follow me.")
      |> close()
      |> cutin("", 255)
      |> warp("kh_school", 120, 180)
    end
  end

  defp identify_friend(ctx) do
    {ctx, proof} =
      ctx
      |> mes("[Allysia]")
      |> mes("Hm? I don't think")
      |> mes("I know you. Kiel Hyre")
      |> mes("has only authorized Elly,")
      |> mes("and a trusted friend that")
      |> mes("may be helping her, to")
      |> mes("be admitted to this area.")
      |> next()
      |> mes("[Allysia]")
      |> mes("I cannot see ^FF0000Elly^000000.")
      |> mes("Has she been attacked as well?")
      |> mes("Are you ^FF0000Elly's friend^000000?")
      |> next()
      |> mes("[Allysia]")
      |> mes("I don't see Elly anywhere")
      |> mes("around here. I can only let")
      |> mes("you enter if you can identify")
      |> mes("yourself as Elly's friend.")
      |> mes("Is there anything that you")
      |> mes("can present to me as proof?")
      |> next()
      |> select(["Yellow Keycard", "Blue Keycard", "Golden Key", "Carved Button", "...?"])

    case proof do
      3 -> accept_friend(ctx)
      4 -> summon_bombs(ctx)
      5 -> remain_silent(ctx)
      _ -> reject_proof(ctx)
    end
  end

  defp accept_friend(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Ah, isn't this the")
    |> mes("key that Kiel Hyre gave")
    |> mes("to Elly? Yes, I'm convinced")
    |> mes("that you've been helping her.")
    |> mes("I've been waiting for you, so")
    |> mes("let me guide you to my room.")
    |> close()
    |> cutin("", 255)
    |> warp("kh_school", 120, 180)
  end

  defp summon_bombs(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Th-that's Kiehl's")
    |> mes("seal! Did he send you")
    |> mes("here to get me?! I'm")
    |> mes("not taking any chances!")
    |> close()
    |> cutin("", 255)
    |> summon_mob(mob_id: 1745, map: "kh_school", at: {117, 144})
    |> summon_mob(mob_id: 1745, map: "kh_school", at: {117, 144})
    |> summon_mob(mob_id: 1745, map: "kh_school", at: {117, 144})
    |> summon_mob(mob_id: 1745, map: "kh_school", at: {117, 144})
  end

  defp remain_silent(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("......")
    |> mes("........")
    |> mes("...........")
    |> close()
    |> cutin("", 255)
  end

  defp reject_proof(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Hm? This doesn't prove")
    |> mes("that Elly really trusts you...")
    |> close()
    |> cutin("", 255)
  end
end

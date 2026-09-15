defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanKid194104 do
  @moduledoc """
  Asks visitors about bungee jumping and explains the Utan adulthood ceremony.

  ## Behavior

  - Speaks intelligibly only after Umbalan language progress reaches stage 3.
  - Welcomes experienced jumpers and explains the ceremony to others.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 194,
        y: 104,
        dir: 4,
        sprite: 787,
        name: "Utan Kid",
        scope: :shared,
        unique_name: "Utan Kid#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ask_about_jumping(ctx)
    else
      ask_in_umbalan(ctx)
    end
  end

  defp ask_about_jumping(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boorkatan]")
      |> mes("Huh? You're from Rune-Midgarts,")
      |> mes("aren't you? Have you ever been bungee jumping?")
      |> next()
      |> select(["Yeah", "No"])

    if choice == 1 do
      ctx
      |> mes("[Boorkatan]")
      |> mes("Whoa, what a surprise! I never")
      |> mes("would have thought someone from")
      |> mes("outside would know how to do it.")
      |> mes("Okay, I'll take your word for")
      |> mes("it and welcome you to our village.")
      |> close()
    else
      ctx
      |> mes("[Boorkatan]")
      |> mes("Er, I see...")
      |> mes("As part of the ceremony of")
      |> mes("adulthood, all Utans have to do")
      |> mes("a bungee jump. When I grow up,")
      |> mes("I'm gonna do it too, and prove")
      |> mes("to everybody that I am a man!")
      |> close()
    end
  end

  defp ask_in_umbalan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[???]")
      |> mes("Umbaumbababah umhumba.")
      |> mes("Umbabaumumba umbaumbah?")
      |> next()
      |> select(["Yeah", "No"])

    if choice == 1 do
      ctx
      |> mes("[???]")
      |> mes("Umba, Umumbah umbabah.")
      |> mes("Umbaumbah umumbabah.")
      |> close()
    else
      ctx
      |> mes("[???]")
      |> mes("Er, Umbahumba umumbah.")
      |> mes("Umbahumbah umbabah.")
      |> mes("Umbahumhumbabahum.")
      |> close()
    end
  end
end

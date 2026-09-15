defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.WizardStanza do
  @moduledoc """
  Warns visitors about magical consequences and recommends protective Gemstones.

  ## Behavior

  - Tailors an introduction to Mages, Acolytes, Novices, and other visitors.
  - Explains the risks of mystical power and the protection Gemstones provide.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 164,
        y: 109,
        dir: 0,
        sprite: 64,
        name: "Wizard Stanza",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Stanza]")
      |> mes("I sense the presence of a mighty spirit. Can it be you...?")
      |> next()
      |> mes("[Stanza]")
      |> address_visitor()

    ctx
    |> next()
    |> mes("[Stanza]")
    |> mes(
      "If you use mystic energy for the purpose of harming others, or to defy the rules set by Mother Nature, that power will naturally be turned against you. Remember, you reap what you sow."
    )
    |> next()
    |> mes("[Stanza]")
    |> mes(
      "But there is an item that can protect the caster from ill consequence, allowing the safe use of certain magics. These are the shining, mystical stones known as Gemstones."
    )
    |> next()
    |> mes("[Stanza]")
    |> mes("Gemstone...")
    |> mes("If you wish to use your powers to the fullest, remember this item.")
    |> close()
  end

  defp address_visitor(ctx) do
    cond do
      base_job(ctx) == :mage ->
        mes(
          ctx,
          "It seems that you are trained in the mystic arts. Magic... Its power is governed by the law of cause and effect."
        )

      base_job(ctx) == :acolyte ->
        ctx
        |> mes("Ah...")
        |> mes(
          "I see that you wield holy power in one way or another. I suppose Holy power may be considered one form of mystical energy."
        )

      class(ctx) == :novice ->
        mes(
          ctx,
          "Although you may not be able to use magic or any other kind of powerful skills for now, this knowledge may be helpful in the future, young Novice..."
        )

      true ->
        mes(
          ctx,
          "Although you are not formally trained in the use of magic, you use skills which draw upon otherworldly energies, whether you know it or not..."
        )
    end
  end
end

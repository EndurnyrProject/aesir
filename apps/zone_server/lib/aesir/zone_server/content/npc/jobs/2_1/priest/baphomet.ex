defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Baphomet do
  @moduledoc """
  Demon that offers Acolytes a pact in exchange for abandoning the Priest spiritual training.

  ## Behavior

  - Dismisses Priests who pass through.
  - Offers Acolytes a contract; accepting warps them out of the training.
  - Refusing the contract lets the Acolyte continue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 168,
        y: 150,
        dir: 4,
        sprite: 736,
        name: "Baphomet",
        scope: :shared,
        unique_name: "Baphomet#prst",
        trigger: {8, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) -> dismiss_priest(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) -> offer_pact(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp dismiss_priest(ctx) do
    ctx
    |> mes("[Baphomet]")
    |> mes("I hate")
    |> mes("Priests...")
    |> next()
    |> mes("[Baphomet]")
    |> mes("I don't have any business with you, servant of God. Just pass through.")
    |> close()
  end

  defp offer_pact(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Baphomet]")
      |> mes("Greetings.")
      |> next()
      |> mes("[Baphomet]")
      |> mes("...#{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Baphomet]")
      |> mes("Yes, human,")
      |> mes("I know who you are.")
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "I also know that Deviruchi, Doppelganger and the Dark Lord have all failed to convince you to turn away from the Priesthood."
      )
      |> mes("Now, I stand before")
      |> mes("you to offer a deal.")
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "I can grant you any treasure you desire and infinite power at your fingertips. Powerful weapons that humans have never before seen..."
      )
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "Mountains of zeny that you cannot possibly hope to spend in a lifetime. Though, who's to say that your lifespan should be limited? Fame, power, immortality: It can all be yours."
      )
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "I will be yours to summon at anytime. All other humans will dread making you their enemy. You will become the most powerful person in all of history!"
      )
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "Cease this foolishness of pursuing the Priesthood. Make a contract with me. The entire world is yours for the taking."
      )
      |> next()
      |> select(["Deal.", "No, Baphomet. You lose."])

    if choice == 1 do
      ctx
      |> mes("[Baphomet]")
      |> mes("Then we shall form a contract. You won't ever regret this moment...")
      |> next()
      |> mes("[Baphomet]")
      |> mes("Follow me.")
      |> mes("We will make the")
      |> mes("contract in my")
      |> mes("sanctum of darkness.")
      |> close()
      |> warp("glast_01", 200, 203)
    else
      ctx
      |> mes("[Baphomet]")
      |> mes("Foolish human...")
      |> mes(
        "You have made your choice. I will leave you alone for now, then. However, your training won't be as easy as you think."
      )
      |> next()
      |> mes("[Baphomet]")
      |> mes(
        "I shall be preparing my troops for you. The day will come when I shall enjoy watching you writhe in agony as my fiends slowly devour you."
      )
      |> close()
    end
  end
end

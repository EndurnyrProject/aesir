defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.ZombieInfo do
  @moduledoc """
  Invisible trigger where Father Peter explains the zombie hall of the Priest spiritual training.

  ## Behavior

  - Tells Priests how to assist their Acolyte within the five-minute limit.
  - Tells Acolytes to slay every zombie before taking the warp at the end of the hall.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) -> brief_priest(ctx)
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) -> brief_acolyte(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp brief_priest(ctx) do
    ctx
    |> mes("[Father Peter]")
    |> mes(
      "When the Priest applicant enters, 5 minutes will be given to complete this trial. Proceed slowly and help your Acolyte."
    )
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "Enter through the warp at the end of the hall, where you will be lead to the next test hall."
    )
    |> next()
    |> mes("[Father Peter]")
    |> mes("Remember...")
    |> mes("This trial must be")
    |> mes("completed within")
    |> mes("5 minutes. Best of luck~")
    |> close()
  end

  defp brief_acolyte(ctx) do
    ctx
    |> mes("[Father Peter]")
    |> mes(
      "I will give you exactly 5 minutes! You must proceed slowly and eliminate the Zombies."
    )
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "Slay all the zombies and go through the warp at the end of the hall. Make sure that you kill them all."
    )
    |> close()
  end
end

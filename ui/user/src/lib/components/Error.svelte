<script lang="ts">
	import { fade } from 'svelte/transition';
	import { parseErrorContent } from '$lib/errors';
	import { AlertCircle, TriangleAlert } from 'lucide-svelte';
	import CopyButton from './CopyButton.svelte';

	interface Props {
		onClick?: (() => void) | null;
		error: Error;
	}

	let { onClick = null, error }: Props = $props();

	// Parse error content to extract status code and categorize
	const errorContent = $derived(parseErrorContent(error));
	const isClientError = $derived(errorContent.status >= 400 && errorContent.status < 500);
	const isServerError = $derived(errorContent.status >= 500);
</script>

<!--error component-->
<div in:fade class="flex items-center justify-center">
	<div
		class="dark:bg-surface2 dark:border-surface3 bg-background flex w-full flex-col items-center gap-4 rounded-lg p-4 dark:border"
	>
		<h3 class="text-on-background text-2xl font-semibold">Error</h3>

		<div
			class="{isServerError
				? 'notification-error'
				: 'notification-alert'} flex w-full items-center gap-2"
		>
			{#if isServerError}
				<AlertCircle class="size-6 text-red-500" />
			{:else if isClientError}
				<TriangleAlert class="size-6 text-yellow-500" />
			{:else}
				<AlertCircle class="size-6 text-red-500" />
			{/if}
			<p class="flex flex-1 flex-col text-sm font-light">
				<span class="font-semibold">Error Details:</span>
				<span class="break-all">
					{error.message}
				</span>
			</p>
			<CopyButton text={error.message} tooltipText="Copy error details" class="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200" />
		</div>

		{#if onClick}
			<button class="text-on-background mt-2 hover:underline" onclick={onClick}>Try again</button>
		{/if}
	</div>
</div>

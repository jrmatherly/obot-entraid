<script lang="ts">
	import { fade } from 'svelte/transition';
	import { parseErrorContent } from '$lib/errors';
	import { AlertCircle, TriangleAlert, X } from 'lucide-svelte';
	import CopyButton from './CopyButton.svelte';
	import { twMerge } from 'tailwind-merge';

	interface Props {
		onClick?: (() => void) | null;
		onClose?: (() => void) | null;
		error: Error;
		classes?: {
			root?: string;
		};
	}

	let { onClick = null, onClose = null, error, classes }: Props = $props();

	// Parse error content to extract status code and categorize
	const errorContent = $derived(parseErrorContent(error));
	const isClientError = $derived(errorContent.status >= 400 && errorContent.status < 500);
	const isServerError = $derived(errorContent.status >= 500);

	// Determine contextual error heading based on error category
	const errorHeading = $derived.by(() => {
		if (isServerError) {
			return 'Server Error';
		} else if (isClientError) {
			return 'Request Failed';
		} else if (!errorContent.status || errorContent.status === 0) {
			return 'Connection Error';
		} else {
			return 'Error Occurred';
		}
	});
</script>

<!--error component-->
<div in:fade class="flex items-center justify-center">
	<div
		class={twMerge(
			"dark:bg-surface2 dark:border-surface3 bg-background relative flex w-full flex-col items-center gap-4 rounded-lg p-4 dark:border",
			classes?.root
		)}
	>
		{#if onClose}
			<button type="button" onclick={onClose} class="icon-button absolute end-2.5 top-3 ms-auto">
				<X class="h-6 w-6" />
				<span class="sr-only">Close error</span>
			</button>
		{/if}
		<h3 class="text-on-background text-2xl font-semibold">{errorHeading}</h3>

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
			<button
				onclick={onClick}
				type="button"
				class="inline-flex min-h-10 items-center rounded-3xl bg-blue-600 px-5 py-2.5 text-center text-sm font-medium text-white hover:bg-blue-800"
			>
				Try again
			</button>
		{/if}
	</div>
</div>
